#ifndef _INCLUDE_EFFECTS
#define _INCLUDE_EFFECTS

//#define NOISE_AND_GRAIN
#ifdef NOISE_AND_GRAIN
void noise_and_grain(inout vec3 color) {
	float r = hash(uv * viewWidth);
	float g = hash(uv * viewWidth + 1000.0);
	float b = hash(uv * viewWidth + 4000.0);
	float w = hash(uv * viewWidth - 1000.0);
	w *= hash(uv * viewWidth - 2000.0);
	w *= hash(uv * viewWidth - 3000.0);

	color = mix(color, vec3(r,g,b) * luma(color), pow(w, 3.0));
}
#endif

//#define EIGHT_BIT
#ifdef EIGHT_BIT
void bit8(sampler2D tex, out vec3 color) {
	vec2 grid = vec2(viewWidth / viewHeight, 1.0) * 120.0;
	vec2 texc = floor(uv * grid) / grid;

	float dither = bayer_16x16(texc, grid);
	vec3 c = texture2D(tex, texc).rgb * 16.0;
	color = floor(c + dither) / 16.0;
}
#endif

//#define FILMIC_CINEMATIC
#define FILMIC_CINEMATIC_ANAMORPHIC
#ifdef FILMIC_CINEMATIC
void filmic_cinematic(inout vec3 color) {
	color = clamp(color, vec3(0.0), vec3(2.0));
	float w = luma(color);

	color = mix(vec3(w), max(color - vec3(w * 0.1), vec3(0.0)), 0.4 + w * 0.8);

	#ifdef BLOOM
	const vec2 center_avr = vec2(0.5) * 0.125 + vec2(0.0f, 0.25f) + vec2(0.000f, 0.025f);
	#define AVR_SOURCE gcolor
	#else
	const vec2 center_avr = vec2(0.5);
	#define AVR_SOURCE gaux2
	#endif
	vec3 center = texture2D(AVR_SOURCE, center_avr).rgb;
	color = pow(color, 0.3 * center + 1.0);
	color /= luma(center) * 0.5 + 0.5;
	color *= (normalize(max(vec3(0.1), center)) * 0.3 + 0.7);

	#ifdef FILMIC_CINEMATIC_ANAMORPHIC
	// 21:9
	if (viewHeight * distance(uv.y, 0.5) > viewWidth * 0.4285714 * 0.5)
		color *= 0.0;
	#endif
}
#endif

#ifdef MOTION_BLUR

#define MOTIONBLUR_MAX 0.1
#define MOTIONBLUR_STRENGTH 0.5
#define MOTIONBLUR_SAMPLE 6

const float dSample = 1.0 / float(MOTIONBLUR_SAMPLE);

void motion_blur(in sampler2D screen, inout vec3 color, in vec2 uv, in vec3 viewPosition) {
	vec4 worldPosition = gbufferModelViewInverse * vec4(viewPosition, 1.0) + vec4(cameraPosition, 0.0);
	vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
	vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
	vec2 prevUv = prevNdcPosition.st * 0.5 + 0.5;
	vec2 delta = uv - prevUv;
	float dist = length(delta) * 0.25;
	if (dist < 0.000025) return;
	delta = normalize(delta);
	dist = min(dist, MOTIONBLUR_MAX);
	int num_sams = int(dist / MOTIONBLUR_MAX * MOTIONBLUR_SAMPLE) + 1;
	dist *= MOTIONBLUR_STRENGTH;
	delta *= dist * dSample;
	for(int i = 1; i < num_sams; i++) {
		uv += delta;
		color += texture2D(screen, uv).rgb;
	}
	color /= float(num_sams);
}
#endif

vec3 applyEffect(float total, float size,
	float a00, float a01, float a02,
	float a10, float a11, float a12,
	float a20, float a21, float a22,
	sampler2D sam, vec2 uv) {

	vec3 color = texture2D(sam, uv).rgb * a11;

	color += texture2D(sam, uv + size * vec2(-pixel.x, pixel.y)).rgb * a00;
	color += texture2D(sam, uv + size * vec2(0.0, pixel.y)).rgb * a01;
	color += texture2D(sam, uv + size * pixel).rgb * a02;
	color += texture2D(sam, uv + size * vec2(-pixel.x, 0.0)).rgb * a10;
	color += texture2D(sam, uv + size * vec2(pixel.x, 0.0)).rgb * a12;
	color += texture2D(sam, uv - size * pixel).rgb * a20;
	color += texture2D(sam, uv + size * vec2(0.0, -pixel.y)).rgb * a21;
	color += texture2D(sam, uv + size * vec2(pixel.x, -pixel.y)).rgb * a22;

	return max(color / total, vec3(0.0));
}

vec3 saturation(vec3 rgbColor, float s) {
	return mix(vec3(luma(rgbColor)), rgbColor, s);
}

#endif
