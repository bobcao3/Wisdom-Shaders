/*
 * Copyright 2017 Cheng Cao
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _INCLUDE_NOISE
#define _INCLUDE_NOISE

uniform sampler2D noisetex;

float16_t hash(f16vec2 p) {
	f16vec3 p3 = fract(vec3(p.xyx) * 0.2031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

//#define TAA

float16_t noise(f16vec2 p) {
	f16vec2 i = floor(p);
	f16vec2 f = fract(p);
	f16vec2 u = (f * f) * fma(f16vec2(-2.0f), f, f16vec2(3.0f));
	return fma(2.0f, mix(
		mix(hash(i),                      hash(i + f16vec2(1.0f,0.0f)), u.x),
		mix(hash(i + f16vec2(0.0f,1.0f)), hash(i + f16vec2(1.0f,1.0f)), u.x),
	u.y), -1.0f);
}

float16_t noise_tex(in f16vec2 p) {
	return fma(texture2D(noisetex, fract(p * 0.0050173)).r, 2.0, -1.0);
}

float16_t bayer2(f16vec2 a){
    a = floor(a);
		#ifdef TAA
		a += mod(frameTimeCounter, 4) * 0.25;
		#endif
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

const f16vec2 poisson_12[12] = f16vec2 [] (
	f16vec2(-0.326212, -0.40581),
	f16vec2(-0.840144, -0.07358),
	f16vec2(-0.695914,  0.457137),
	f16vec2(-0.203345,  0.620716),
	f16vec2(0.96234,   -0.194983),
	f16vec2(0.473434,  -0.480026),
	f16vec2(0.519456,   0.767022),
	f16vec2(0.185461,  -0.893124),
	f16vec2(0.507431,   0.064425),
	f16vec2(0.89642,    0.412458),
	f16vec2(-0.32194,  -0.932615),
	f16vec2(-0.791559, -0.59771)
);

const f16vec2 poisson_4[4] = f16vec2 [] (
	f16vec2(-0.94201624, -0.39906216 ),
	f16vec2( 0.94558609, -0.76890725 ),
	f16vec2(-0.09418410, -0.92938870 ),
	f16vec2( 0.34495938,  0.29387760 )
);

// 4x4 bicubic filter using 4 bilinear texture lookups
// See GPU Gems 2: "Fast Third-Order Texture Filtering", Sigg & Hadwiger:
// http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter20.html

// w0, w1, w2, and w3 are the four cubic B-spline basis functions
float w0(float a) {
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a) {
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a) {
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a) {
    return (1.0/6.0)*(a*a*a);
}

// g0 and g1 are the two amplitude functions
float g0(float a) {
    return w0(a) + w1(a);
}

float g1(float a) {
    return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a) {
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a) {
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

#endif
