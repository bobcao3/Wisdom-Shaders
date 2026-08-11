#version 430 compatibility

// One workgroup builds a center-weighted log-luminance histogram from the
// final HDR scene and updates persistent exposure state in an SSBO.
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;
const ivec3 workGroups = ivec3(1, 1, 1);

uniform sampler2D composite;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTime;
uniform int frameCounter;

const int HISTOGRAM_BINS = 128;
const float MIN_LOG_LUMINANCE = -12.0;
const float MAX_LOG_LUMINANCE = 8.0;
const uint EXPOSURE_STATE_MAGIC = 0x41575833u;

shared uint luminanceHistogram[HISTOGRAM_BINS];
shared uint highlightHistogram[HISTOGRAM_BINS];

layout(std430, binding = 0) buffer ExposureState {
	float adaptedExposure;
	float targetExposure;
	float medianLuminance;
	uint initialized;
} exposureState;

float luminance(vec3 color) {
	return dot(max(color, vec3(0.0)), vec3(0.2126, 0.7152, 0.0722));
}

void main() {
	uint invocation = gl_LocalInvocationIndex;
	if (invocation < uint(HISTOGRAM_BINS)) {
		luminanceHistogram[invocation] = 0u;
		highlightHistogram[invocation] = 0u;
	}
	barrier();

	int gridWidth = 96;
	int gridHeight = clamp(int(round(float(gridWidth) * viewHeight / max(viewWidth, 1.0))), 32, 96);
	int sampleCount = gridWidth * gridHeight;

	for (int sampleIndex = int(invocation); sampleIndex < sampleCount; sampleIndex += 256) {
		ivec2 samplePixel = ivec2(sampleIndex % gridWidth, sampleIndex / gridWidth);
		vec2 uv = (vec2(samplePixel) + 0.5) / vec2(gridWidth, gridHeight);

		// Mip 3 provides an HDR-preserving spatial prefilter before statistics.
		float sceneLuminance = max(luminance(textureLod(composite, uv, 3.0).rgb), exp2(MIN_LOG_LUMINANCE));
		float normalizedLog = clamp(
			(log2(sceneLuminance) - MIN_LOG_LUMINANCE) / (MAX_LOG_LUMINANCE - MIN_LOG_LUMINANCE),
			0.0,
			0.999999
		);
		uint bin = uint(normalizedLog * float(HISTOGRAM_BINS));
		atomicAdd(highlightHistogram[bin], 1u);

		// Every part of the image contributes. The center receives up to four
		// times the edge weight without becoming a narrow spot meter.
		vec2 centered = (uv - 0.5) * 2.0;
		float centerWeight = exp(-2.0 * dot(centered, centered));
		uint weight = uint(round(mix(4.0, 16.0, centerWeight)));
		atomicAdd(luminanceHistogram[bin], weight);
	}
	barrier();

	if (invocation == 0u) {
		uint totalWeight = 0u;
		for (int bin = 0; bin < HISTOGRAM_BINS; ++bin) {
			totalWeight += luminanceHistogram[bin];
		}

		uint medianThreshold = (totalWeight + 1u) / 2u;
		uint cumulativeWeight = 0u;
		int medianBin = HISTOGRAM_BINS / 2;
		for (int bin = 0; bin < HISTOGRAM_BINS; ++bin) {
			cumulativeWeight += luminanceHistogram[bin];
			if (cumulativeWeight >= medianThreshold) {
				medianBin = bin;
				break;
			}
		}

		// An unweighted percentile catches small off-center sources without
		// turning the meter into a spot meter.
		uint highlightThreshold = uint(ceil(0.99 * float(sampleCount)));
		uint highlightCumulative = 0u;
		int highlightBin = HISTOGRAM_BINS - 1;
		for (int bin = 0; bin < HISTOGRAM_BINS; ++bin) {
			highlightCumulative += highlightHistogram[bin];
			if (highlightCumulative >= highlightThreshold) {
				highlightBin = bin;
				break;
			}
		}

		float medianLog = mix(
			MIN_LOG_LUMINANCE,
			MAX_LOG_LUMINANCE,
			(float(medianBin) + 0.5) / float(HISTOGRAM_BINS)
		);
		float median = exp2(medianLog);
		float highlightLog = mix(
			MIN_LOG_LUMINANCE,
			MAX_LOG_LUMINANCE,
			(float(highlightBin) + 0.5) / float(HISTOGRAM_BINS)
		);
		float highlightLuminance = exp2(highlightLog);
		// Partial compensation keeps dark scenes dark and bright scenes bright;
		// the EV clamp bounds adaptation to 1/4x through 8x.
		float adaptationEv = clamp(log2(0.13 / max(median, 1e-5)) * 0.55, -2.0, 3.0);
		float medianTarget = exp2(adaptationEv);
		float highlightTarget = 3.0 / max(highlightLuminance, 1e-5);
		float target = medianTarget;
		if (highlightTarget < medianTarget) {
			float highlightPressure = medianTarget / highlightTarget;
			float protection = 0.65 * smoothstep(1.0, 4.0, highlightPressure);
			target = exp2(mix(log2(medianTarget), log2(highlightTarget), protection));
		}
		target = clamp(target, 0.0625, 16.0);

		bool stateValid = exposureState.initialized == EXPOSURE_STATE_MAGIC
			&& !isnan(exposureState.adaptedExposure)
			&& !isinf(exposureState.adaptedExposure)
			&& exposureState.adaptedExposure > 0.0;

		if (!stateValid || frameCounter <= 1) {
			exposureState.adaptedExposure = target;
		} else {
			float deltaTime = clamp(frameTime, 0.0, 0.1);
			// Bright scenes reduce exposure quickly; dark adaptation is slower.
			float adaptationRate = target < exposureState.adaptedExposure ? 3.0 : 1.25;
			float adaptation = 1.0 - exp(-adaptationRate * deltaTime);
			exposureState.adaptedExposure = mix(exposureState.adaptedExposure, target, adaptation);
		}

		exposureState.targetExposure = target;
		exposureState.medianLuminance = median;
		exposureState.initialized = EXPOSURE_STATE_MAGIC;
		memoryBarrierBuffer();
	}
}
