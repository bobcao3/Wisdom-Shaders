#ifndef _INCLUDE_UTILITY
#define _INCLUDE_UTILITY

const float PI = 3.14159265f;

varying vec3 suncolor;
varying vec3 ambient;
varying float extShadow;
varying vec3 worldLightPosition;

varying float cloud_coverage;
varying float wind_speed;

#define hash_fast(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

float16_t hash(f16vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.2031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float16_t noise(f16vec2 p) {
	f16vec2 i = floor(p);
	f16vec2 f = fract(p);
	f16vec2 u = (f * f) * fma(f16vec2(-2.0f), f, f16vec2(3.0f));
	return fma(2.0f, mix(
		mix(hash(i),                      hash(i + f16vec2(1.0f,0.0f)), u.x),
		mix(hash(i + f16vec2(0.0f,1.0f)), hash(i + f16vec2(1.0f,1.0f)), u.x),
	u.y), -1.0f);
}

//==============================================================================
// Vertex stuff
//==============================================================================
#ifdef _VERTEX_SHADER_

uniform int worldTime;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform int moonPhase;

uniform float wetness;

uniform vec3 shadowLightPosition;

uniform mat4 gbufferModelViewInverse;

uniform sampler2D noisetex;

void calcCommons() {
	float wTimeF = float(worldTime);

	float TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	float TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0);
	float TimeMidnight = ((clamp(wTimeF, 12500.0, 12750.0) - 12500.0) / 250.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	const vec3 suncolor_sunrise = vec3(0.9243, 0.4, 0.0913) * 3.22;
	const vec3 suncolor_noon = vec3(1.2311, 1.0, 0.8286) * 4.3;
	const vec3 suncolor_sunset = vec3(0.9943, 0.419, 0.0945) * 3.6;
	const vec3 suncolor_midnight = vec3(0.34, 0.5, 0.6) * 0.4;

	float day = wTimeF / 24000.0;
	float day_cycle = mix(float(moonPhase), mod(float(moonPhase + 1), 8.0), day) + frameTimeCounter * 0.0001;
	cloud_coverage = mix(noise(vec2(day_cycle, 0.0)) * 0.3 + 0.1, 0.7, max(rainStrength, wetness));
	wind_speed = mix(noise(vec2(day_cycle * 2.0, 0.0)) * 0.5 + 1.0, 2.0, rainStrength);

	suncolor = suncolor_sunrise * TimeSunrise + suncolor_noon * TimeNoon + suncolor_sunset * TimeSunset + suncolor_midnight * TimeMidnight;
	suncolor *= 1.0 - cloud_coverage;
	extShadow = (clamp((wTimeF-12350.0)/100.0,0.0,1.0)-clamp((wTimeF-13050.0)/100.0,0.0,1.0) + clamp((wTimeF-22800.0)/200.0,0.0,1.0)-clamp((wTimeF-23400.0)/200.0,0.0,1.0));

	#ifndef SPACE
	const vec3 ambient_sunrise = vec3(0.543, 0.772, 0.786) * 0.27;
	const vec3 ambient_noon = vec3(0.686, 0.702, 0.73) * 0.34;
	const vec3 ambient_sunset = vec3(0.543, 0.772, 0.747) * 0.26;
	const vec3 ambient_midnight = vec3(0.06, 0.088, 0.117) * 0.1;

	ambient = ambient_sunrise * TimeSunrise + ambient_noon * TimeNoon + ambient_sunset * TimeSunset + ambient_midnight * TimeMidnight;
	#else
	ambient = vec3(0.0);
	suncolor = vec3(1.0);
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

const vec3 agamma = vec3(0.8 / gamma);

float luma(in vec3 color) { return dot(color,vec3(0.2126, 0.7152, 0.0722)); }

#define EXPOSURE 1.4 // [1.0 1.2 1.4 1.6 1.8]

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
	//color = pow(color, vec3(1.07, 1.04, 1.0));

	#ifdef VIGNETTE
	color = vignette(color);
	#endif

	color = pow(color, agamma);
}

//==============================================================================
// Light utilities
//==============================================================================

#define AVERAGE_EXPOSURE
#ifdef AVERAGE_EXPOSURE
float get_exposure() {
	float basic_exp = EXPOSURE * (1.8 - clamp(pow(eyeBrightnessSmooth.y / 240.0, 6.0) * luma(suncolor), 0.0, 1.2));

	#ifdef BLOOM
	vec3 center = texture2D(gcolor, vec2(0.5) * 0.125 + vec2(0.0f, 0.25f) + vec2(0.000f, 0.025f)).rgb;
	#else
	vec3 center = texture2D(composite, vec2(0.5)).rgb;
	#endif
	float avr_exp = (0.5 - clamp(luma(center), 0.0, 2.0)) * 1.5;
	basic_exp = mix(basic_exp, max(0.1, basic_exp + avr_exp), 0.8);

	return basic_exp;
}
#else
float get_exposure() {
	return EXPOSURE * (1.8 - clamp(pow(eyeBrightnessSmooth.y / 240.0, 6.0) * luma(suncolor), 0.0, 1.2));
}
#endif

//==============================================================================
// Vector stuff
//==============================================================================

float fov = atan(1./gbufferProjection[1][1]);
float mulfov = isEyeInWater ? gbufferProjection[1][1]*tan(fov * 0.85):1.0;

vec4 fetch_vpos (vec2 uv, float z) {
	vec4 v = gbufferProjectionInverse * vec4(fma(vec3(uv, z), vec3(2.0f), vec3(-1.0)), 1.0);
	v /= v.w;
	v.xy *= mulfov;

	return v;
}

vec4 fetch_vpos (vec2 uv, sampler2D sam) {
	return fetch_vpos(uv, texture2D(sam, uv).x);
}

float16_t linearizeDepth(float16_t depth) { return (2.0 * near) / (far + near - depth * (far - near));}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(fma(p.z, 0.5f, 0.5f));
}

f16vec2 screen_project (vec3 vpos) {
	f16vec4 p = f16mat4(gbufferProjection) * f16vec4(vpos, 1.0f);
	p /= p.w;
	if(abs(p.z) > 1)
		return f16vec2(-1.0);
	return fma(p.st, vec2(0.5f), vec2(0.5f));
}

#endif

float noise_tex(in vec2 p) {
	return fma(texture2D(noisetex, fract(p * 0.0020173)).r, 2.0, -1.0);
}

float16_t bayer2(f16vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5f, a.y * .75f)) );
}

#define bayer4(a)   (bayer2( .5f*(a))*.25f+bayer2(a))
#define bayer8(a)   (bayer4( .5f*(a))*.25f+bayer2(a))
#define bayer16(a)  (bayer8( .5f*(a))*.25f+bayer2(a))
#define bayer32(a)  (bayer16(.5f*(a))*.25f+bayer2(a))
#define bayer64(a)  (bayer32(.5f*(a))*.25f+bayer2(a))

float16_t bayer_4x4(in f16vec2 pos, in f16vec2 view) {
	return bayer4(pos * view);
}

float16_t bayer_8x8(in f16vec2 pos, in f16vec2 view) {
	return bayer8(pos * view);
}

float16_t bayer_16x16(in f16vec2 pos, in f16vec2 view) {
	return bayer16(pos * view);
}

float16_t bayer_32x32(in f16vec2 pos, in f16vec2 view) {
	return bayer32(pos * view);
}

float16_t bayer_64x64(in f16vec2 pos, in f16vec2 view) {
	return bayer64(pos * view);
}

f16vec2 hash22(f16vec2 p){
    f16vec2 p2 = fract(p * vec2(.1031f,.1030f));
    p2 += dot(p2, p2.yx+19.19f);
    return fract((p2.x+p2.y)*p2);
}

float simplex2D(vec2 p){
    const float K1 = (sqrt(3.)-1.)/2.;
    const float K2 = (3.-sqrt(3.))/6.;
    const float K3 = K2*2.;

    vec2 i = floor( p + dot(p,vec2(K1)) );

    vec2 a = p - i + dot(i,vec2(K2));
    vec2 o = 1.-clamp((a.yx-a)*1.e35,0.,1.);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + K3;

    vec3 h = clamp( .5-vec3(dot(a,a), dot(b,b), dot(c,c) ), 0. ,1. );

    h*=h;
    h*=h;

    vec3 n = vec3(
        dot(a,hash22(i   )-.5),
        dot(b,hash22(i+o )-.5),
        dot(c,hash22(i+1.)-.5)
    );

    return dot(n,h)*140.;
}

#define Positive(a) max(0.0000001, a)

#endif
