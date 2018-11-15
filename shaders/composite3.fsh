#version 130

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

#include "libs/compat.glsl"
#pragma optimize(on)

varying vec2 uv;

#include "GlslConfig"

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
//#include "libs/Lighting.frag"

//#define CrespecularRays
//#include "libs/atmosphere.glsl"

const bool colortex3Clear = false;

#define BLOOM
#ifdef BLOOM
const float padding = 0.02f;

bool checkBlur(vec2 offset, float scale) {
	return
	(  (uv.s - offset.s + padding < 1.0f / scale + (padding * 2.0f))
	&& (uv.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)) );
}

#ifdef HIGH_LEVE_SHADER
const float weight[4] = float[] (0.3829, 0.2417, 0.0606, 0.02);
#else
const float weight[7] = float[] (0.02, 0.0606, 0.2417, 0.3829, 0.2417, 0.0606, 0.02);
#endif

#define BLUR_X(i, abs_i) \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i, -3)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[3]; \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i, -2)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[2]; \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i, -1)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[1]; \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i,  0)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[0]; \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i,  1)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[1]; \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i,  2)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[2]; \
		bloom += clamp(textureOffset(gaux2, finalCoord, ivec2(i,  3)).rgb, vec3(0.0f), vec3(2.0f)) * weight[abs_i] * weight[3];

vec3 LODblur(const float LOD, const vec2 offset) {
	float scale = exp2(LOD);
	vec3 bloom = vec3(0.0);

	float allWeights = 0.0f;

	vec2 finalCoord = (uv.st - offset.st) * scale;

	BLUR_X(-3, 3);
	BLUR_X(-2, 2);
	BLUR_X(-1, 1);
	BLUR_X( 0, 0);
	BLUR_X( 1, 1);
	BLUR_X( 2, 2);
	BLUR_X( 3, 3);
	
	return bloom;
}
#endif

#define TAA

void main() {
/* DRAWBUFFERS:03 */
// bloom
	#ifdef BLOOM
	vec3 blur = vec3(0.0);
	/* LOD 2 */
	if (uv.y < 0.25 + padding && uv.x < 0.25 + padding) {
		blur = LODblur(2.0, vec2(0.0f));
	}
	gl_FragData[0] = vec4(blur, luma(blur));
	#endif
	#ifdef TAA
	gl_FragData[1] = max(vec4(texture2D(gaux2, uv).rgb, texture2D(depthtex0, uv).r), vec4(0.0));
	#endif
}
