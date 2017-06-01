#ifndef _INCLUDE_EFFECTS
#define _INCLUDE_EFFECTS

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
	color += texture2D(sam, uv + size * pixel).rgb * a00;
	color += texture2D(sam, uv + size * vec2(-pixel.x, 0.0)).rgb * a00;
	color += texture2D(sam, uv + size * vec2(pixel.x, 0.0)).rgb * a00;
	color += texture2D(sam, uv - size * pixel).rgb * a00;
	color += texture2D(sam, uv + size * vec2(0.0, -pixel.y)).rgb * a01;
	color += texture2D(sam, uv + size * vec2(pixel.x, -pixel.y)).rgb * a00;
	
	return clamp(color / total, vec3(0.0), vec3(3.0));
}

#endif
