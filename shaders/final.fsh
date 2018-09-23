#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 tex;
vec2 texcoord = tex;

#include "GlslConfig"

#define MOTION_BLUR
#define BLOOM

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Effects.glsl.frag"

//#define BLACK_AND_WHITE

#define LF
#ifdef LF
// =========== LF ===========

uniform float aspectRatio;

varying float sunVisibility;
varying vec2 lf1Pos;
varying vec2 lf2Pos;
varying vec2 lf3Pos;
varying vec2 lf4Pos;

#define MANHATTAN_DISTANCE(DELTA) abs(DELTA.x)+abs(DELTA.y)

#define LENS_FLARE(COLOR, UV, LFPOS, LFSIZE, LFCOLOR) { \
				vec2 delta = UV - LFPOS; delta.x *= aspectRatio; \
				if(MANHATTAN_DISTANCE(delta) < LFSIZE * 2.0) { \
					float d = max(LFSIZE - sqrt(dot(delta, delta)), 0.0); \
					COLOR += LFCOLOR.rgb * LFCOLOR.a * smoothstep(0.0, LFSIZE * 0.25, d) * sunVisibility;\
				} }

#define LF1SIZE 0.026
#define LF2SIZE 0.03
#define LF3SIZE 0.05

const vec4 LF1COLOR = vec4(1.0, 1.0, 1.0, 0.05);
const vec4 LF2COLOR = vec4(1.0, 0.6, 0.4, 0.03);
const vec4 LF3COLOR = vec4(0.2, 0.6, 0.8, 0.05);

vec3 lensFlare(vec3 color, vec2 uv) {
	if(sunVisibility <= 0.0)
		return color;
	LENS_FLARE(color, uv, lf1Pos, LF1SIZE, (LF1COLOR * vec4(suncolor, 1.0) * (1.0 - extShadow)));
	LENS_FLARE(color, uv, lf2Pos, LF2SIZE, (LF2COLOR * vec4(suncolor, 1.0) * (1.0 - extShadow)));
	LENS_FLARE(color, uv, lf3Pos, LF3SIZE, (LF3COLOR * vec4(suncolor, 1.0) * (1.0 - extShadow)));
	return color;
}

#endif
// ==========================

#define SATURATION 2.0 // [0.6 1.0 1.5 2.0]

#define SCREEN_RAIN_DROPS
//#define DISTORTION_FIX

uniform float nightVision;
uniform float blindness;

//uniform float aspectRatio;

#ifdef DISTORTION_FIX
varying vec3 vUV;
varying vec2 vUVDot;
#endif

void main() {
	#ifdef DISTORTION_FIX
	vec3 distort = dot(vUVDot, vUVDot) * vec3(-0.5, -0.5, -1.0) + vUV;
	texcoord = distort.xy / distort.z;
	#endif
	#ifdef SCREEN_RAIN_DROPS
	float real_strength = rainStrength * smoothstep(0.8, 1.0, float(eyeBrightness.y) / 240.0);
	if (rainStrength > 0.0) {
		vec2 adj_tex = texcoord * vec2(aspectRatio, 1.0);
		float n = noise((adj_tex + vec2(0.1, 1.0) * frameTimeCounter) * 2.0);
		n -= 0.6 * abs(noise((adj_tex * 2.0 + vec2(0.1, 1.0) * frameTimeCounter) * 3.0));
		n *= (n * n) * (n * n);
		n *= real_strength * 0.007;
		vec2 uv = texcoord + vec2(n, -n);
		texcoord = mix(uv, texcoord, pow(abs(uv - vec2(0.5)) * 2.0, vec2(2.0)));
	}
	#endif

	#ifdef EIGHT_BIT
	vec3 color;
	bit8(color);
	#else
	vec3 color = texture2D(composite, texcoord).rgb;
	#endif

	#ifdef MOTION_BLUR
	if (texture2D(gaux1, texcoord).a > 0.11) motion_blur(composite, color, texcoord, fetch_vpos(texcoord, depthtex0).xyz);
	#endif

	#ifdef DOF
	dof(color);
	#endif

	float exposure = get_exposure();

	#ifdef BLOOM
	vec3 b = bloom(color);
	color += max(vec3(0.0), b) * exposure * (1.0 + float(isEyeInWater));
	#endif

	#ifdef LF
	color = lensFlare(color, texcoord);
	#endif

	// This will turn it into gamma space
	#ifdef BLACK_AND_WHITE
	color = vec3(luma(color));
	#endif

	#ifdef NOISE_AND_GRAIN
	noise_and_grain(color);
	#endif

	#ifdef FILMIC_CINEMATIC
	filmic_cinematic(color);
	#endif

	tonemap(color, exposure);
	// Apply night vision gamma
	color = pow(color, vec3(1.0 - nightVision * 0.6));
	// Apply blindness
	color = pow(color, vec3(1.0 + blindness));

	saturation(color, SATURATION);

	gl_FragColor = vec4(color, 1.0f);
}
