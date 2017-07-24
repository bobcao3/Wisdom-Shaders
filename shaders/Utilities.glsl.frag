#ifndef _INCLUDE_UTILITY
#define _INCLUDE_UTILITY

const float PI = 3.14159265f;

varying vec3 suncolor;
varying vec3 ambient;
varying float extShadow;
varying vec3 worldLightPosition;

//==============================================================================
// Vertex stuff
//==============================================================================
#ifdef _VERTEX_SHADER_

uniform int worldTime;
uniform float rainStrength;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelViewInverse;

uniform sampler2D noisetex;

void calcCommons() {
	float wTimeF = float(worldTime);

	float TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	float TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	float TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	const vec3 suncolor_sunrise = vec3(0.8843, 0.6, 0.313) * 2.72;
	const vec3 suncolor_noon = vec3(1.392, 1.3235, 1.1156) * 4.4;
	const vec3 suncolor_sunset = vec3(0.9943, 0.419, 0.0945) * 2.6;
	const vec3 suncolor_midnight = vec3(0.34, 0.5, 0.6) * 0.4;

	suncolor = suncolor_sunrise * TimeSunrise + suncolor_noon * TimeNoon + suncolor_sunset * TimeSunset + suncolor_midnight * TimeMidnight;
	suncolor *= 1.0 - rainStrength * 0.67;
	extShadow = (clamp((wTimeF-12000.0)/300.0,0.0,1.0)-clamp((wTimeF-13000.0)/300.0,0.0,1.0) + clamp((wTimeF-22800.0)/200.0,0.0,1.0)-clamp((wTimeF-23400.0)/200.0,0.0,1.0));

	#ifndef SPACE
	const vec3 ambient_sunrise = vec3(0.543, 0.672, 0.886) * 0.15;
	const vec3 ambient_noon = vec3(0.676, 0.792, 1.0) * 0.3;
	const vec3 ambient_sunset = vec3(0.443, 0.772, 0.847) * 0.15;
	const vec3 ambient_midnight = vec3(0.03, 0.078, 0.117) * 0.2;

	ambient = ambient_sunrise * TimeSunrise + ambient_noon * TimeNoon + ambient_sunset * TimeSunset + ambient_midnight * TimeMidnight;
	ambient *= 1.0 - rainStrength * 0.41;
	#else
	const vec3 ambient_sunrise = vec3(0.543, 0.672, 0.886) * 0.05;
	const vec3 ambient_noon = vec3(0.676, 0.792, 1.0) * 0.1;
	const vec3 ambient_sunset = vec3(0.443, 0.772, 0.847) * 0.05;
	const vec3 ambient_midnight = vec3(0.03, 0.078, 0.117) * 0.06;

	ambient = ambient_sunrise * TimeSunrise + ambient_noon * TimeNoon + ambient_sunset * TimeSunset + ambient_midnight * TimeMidnight;
	#endif
	
	worldLightPosition = mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);
}

#else
//==============================================================================
// Fragment stuff
//==============================================================================

const vec2 circle_offsets[25] = vec2[25](
	vec2(-0.48946f,-0.35868f),
	vec2(-0.17172f, 0.62722f),
	vec2(-0.47095f,-0.01774f),
	vec2(-0.99106f, 0.03832f),
	vec2(-0.21013f, 0.20347f),
	vec2(-0.78895f,-0.56715f),
	vec2(-0.10378f,-0.15832f),
	vec2(-0.57284f, 0.3417f ),
	vec2(-0.18633f, 0.5698f ),
	vec2( 0.35618f, 0.00714f),
	vec2( 0.28683f,-0.54632f),
	vec2(-0.4641f ,-0.88041f),
	vec2( 0.19694f, 0.6237f ),
	vec2( 0.69991f, 0.6357f ),
	vec2(-0.34625f, 0.89663f),
	vec2( 0.1726f , 0.28329f),
	vec2( 0.41492f, 0.8816f ),
	vec2( 0.1369f ,-0.97162f),
	vec2(-0.6272f , 0.67213f),
	vec2(-0.8974f , 0.42719f),
	vec2( 0.55519f, 0.32407f),
	vec2( 0.94871f, 0.26051f),
	vec2( 0.71401f,-0.3126f ),
	vec2( 0.04403f, 0.93637f),
	vec2( 0.62031f,-0.66735f)
);
const float circle_count = 25.0;

// Color adjustment

const vec3 agamma = vec3(0.7 / gamma);

float luma(in vec3 color) { return dot(color,vec3(0.2126, 0.7152, 0.0722)); }

#define EXPOSURE 2.0 // [1.0 2.0 3.0]

#define VIGNETTE
#ifdef VIGNETTE
vec3 vignette(vec3 color) {
    float dist = distance(texcoord, vec2(0.5f));
    dist = dist * 1.7 - 0.65;
    dist = smoothstep(0.0, 1.0, dist);
    return color.rgb * (1.0 - dist);
}
#endif

void tonemap(inout vec3 color, float adapted_lum) {
	color *= adapted_lum;

	const float a = 2.51f;
	const float b = 0.03f;
	const float c = 2.43f;
	const float d = 0.59f;
	const float e = 0.14f;
	color = (color*(a*color+b))/(color*(c*color+d)+e);
	//color = clamp(color, vec3(0.0), vec3(1.0));
	color = pow(color, vec3(1.3, 1.20, 1.0));
	
	#ifdef VIGNETTE
	color = vignette(color);
	#endif
	
	color = pow(color, agamma);
}

//==============================================================================
// Light utilities
//==============================================================================

float get_exposure() {
	return EXPOSURE * (1.6 - clamp(pow(eyeBrightnessSmooth.y / 240.0, 6.0) * 0.8 * luma(suncolor), 0.0, 1.0));
}

//==============================================================================
// Vector stuff
//==============================================================================

float fov = atan(1./gbufferProjection[1][1]);
float fovUnderWater = fov * 0.85;
float mulfov = isEyeInWater == true ? gbufferProjection[1][1]*tan(fovUnderWater):1.0;

vec4 fetch_vpos (vec2 uv, float z) {
	vec4 v = gbufferProjectionInverse * vec4(vec3(uv, z) * 2.0 - 1.0, 1.0);
	v /= v.w;
	v.xy *= mulfov;
	
	return v;
}

vec4 fetch_vpos (vec2 uv, sampler2D sam) {
	return fetch_vpos(uv, texture2D(sam, uv).x);
}

float linearizeDepth(float depth) { return (2.0 * near) / (far + near - depth * (far - near));}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(p.z * 0.5 + 0.5);
}

vec2 screen_project (vec3 vpos) {
	vec4 p = gbufferProjection * vec4(vpos, 1.0);
	p /= p.w;
	if(abs(p.z) > 1)
		return vec2(-1.0);
	return p.st * 0.5f + 0.5f;
}

#endif

#define hash_fast(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

float hash(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * 0.2031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0 + 2.0 * mix(
		mix(hash(i),                 hash(i + vec2(1.0,0.0)), u.x),
		mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x),
	u.y);
}

float noise_tex(in vec2 p) {
	return texture2D(noisetex, fract(p * 0.0020173)).r * 2.0 - 1.0;
}

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))

float bayer_4x4(in vec2 pos, in vec2 view) {
	return bayer4(pos * view);
}

float bayer_8x8(in vec2 pos, in vec2 view) {
	return bayer8(pos * view);
}

float bayer_16x16(in vec2 pos, in vec2 view) {
	return bayer16(pos * view);
}

#endif

#define Positive(a) max(0.0000001, a)
