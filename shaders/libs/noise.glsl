#ifndef _INCLUDE_NOISE
#define _INCLUDE_NOISE

uniform sampler2D noisetex;

float hash(float n) { return fract(sin(n) * 1e4); }

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.2031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = (f * f) * fma(vec2(-2.0f), f, vec2(3.0f));
	return fma(2.0f, mix(
		mix(hash(i),                      hash(i + vec2(1.0f,0.0f)), u.x),
		mix(hash(i + vec2(0.0f,1.0f)), hash(i + vec2(1.0f,1.0f)), u.x),
	u.y), -1.0f);
}

float noise(vec3 x) {
	const vec3 step = vec3(110, 241, 171);

	vec3 i = floor(x);
	vec3 f = fract(x);
 
	// For performance, compute the base input to a 1D hash from the integer part of the argument and the 
	// incremental change to the 1D based on the 3D -> 1D wrapping
    float n = dot(i, step);

	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix( hash(n + dot(step, vec3(0, 0, 0))), hash(n + dot(step, vec3(1, 0, 0))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 0))), hash(n + dot(step, vec3(1, 1, 0))), u.x), u.y),
               mix(mix( hash(n + dot(step, vec3(0, 0, 1))), hash(n + dot(step, vec3(1, 0, 1))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 1))), hash(n + dot(step, vec3(1, 1, 1))), u.x), u.y), u.z);
}

float Halton(int b, int i) {
    float r = 0.0;
    float f = 1.0;
    while (i > 0) {
        f = f / float(b);
        r = r + f * float(i % b);
        i = int(floor(float(i) / float(b)));
    }
    return r;
}

float noise_tex(in vec2 p) {
	return fma(texture2D(noisetex, fract(p * 0.0050173)).r, 2.0, -1.0);
}

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5f, a.y * .75f)) );
}

#define bayer4(a)   (bayer2( .5f*(a))*.25f+bayer2(a))
#define bayer8(a)   (bayer4( .5f*(a))*.25f+bayer2(a))
#define bayer16(a)  (bayer8( .5f*(a))*.25f+bayer2(a))
#define bayer32(a)  (bayer16(.5f*(a))*.25f+bayer2(a))
#define bayer64(a)  (bayer32(.5f*(a))*.25f+bayer2(a))

float bayer_4x4(in vec2 pos, in vec2 view) {
	return bayer4(pos * view);
}

float bayer_8x8(in vec2 pos, in vec2 view) {
	return bayer8(pos * view);
}

float bayer_16x16(in vec2 pos, in vec2 view) {
	return bayer16(pos * view);
}

float bayer_32x32(in vec2 pos, in vec2 view) {
	return bayer32(pos * view);
}

float bayer_64x64(in vec2 pos, in vec2 view) {
	return bayer64(pos * view);
}

const vec2 poisson_12[12] = vec2 [] (
	vec2(-0.326212, -0.40581),
	vec2(-0.840144, -0.07358),
	vec2(-0.695914,  0.457137),
	vec2(-0.203345,  0.620716),
	vec2(0.96234,   -0.194983),
	vec2(0.473434,  -0.480026),
	vec2(0.519456,   0.767022),
	vec2(0.185461,  -0.893124),
	vec2(0.507431,   0.064425),
	vec2(0.89642,    0.412458),
	vec2(-0.32194,  -0.932615),
	vec2(-0.791559, -0.59771)
);

const vec2 poisson_4[4] = vec2 [] (
	vec2(-0.94201624, -0.39906216 ),
	vec2( 0.94558609, -0.76890725 ),
	vec2(-0.09418410, -0.92938870 ),
	vec2( 0.34495938,  0.29387760 )
);

#endif
