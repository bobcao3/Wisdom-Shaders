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
	vec3 p3 = fract(vec3(p.xyx) * 0.2031);
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

float noise_tex(in vec2 p) {
	return fma(texture2D(noisetex, fract(p * 0.0020173)).r, 2.0, -1.0);
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
#endif
