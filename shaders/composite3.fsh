#version 120

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

#pragma optimize(on)
#include "libs/compat.glsl"

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

#define BLOOM
#ifdef BLOOM
const float padding = 0.02f;

bool checkBlur(vec2 offset, float scale) {
	return
	(  (uv.s - offset.s + padding < 1.0f / scale + (padding * 2.0f))
	&& (uv.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)) );
}

const float weight[4] = float[] (0.3829, 0.2417, 0.0606, 0.02);

vec3 LODblur(in int LOD, in vec2 offset) {
	float scale = exp2(LOD);
	vec3 bloom = vec3(0.0);

	float allWeights = 0.0f;

	for (int i = -3; i < 4; i++) {
		for (int j = -3; j < 4; j++) {
			vec2 coord = vec2(i, j) / vec2(viewWidth, viewHeight) * 1.0;
			//d1 = fract(d1 + 0.3117);

			vec2 finalCoord = (uv.st + coord.st - offset.st) * scale;

			vec3 c = clamp(texture2DLod(gaux2, finalCoord, 0.0).rgb, vec3(0.0f), vec3(1.0f)) * weight[abs(i)] * weight[abs(j)];

			bloom += c;
		}
	}

	return bloom;
}
#endif

void main() {
/* DRAWBUFFERS:0 */
// bloom
	#ifdef BLOOM
	vec3 blur = vec3(0.0);
	/* LOD 2 */
	float lod = 2.0; vec2 offset = vec2(0.0f);
	if (uv.y < 0.25 + padding * 2.0 + 0.6251 && uv.x < 0.0078125 + 0.25f + 0.100f) {
		if (uv.y > 0.25 + padding) {
			lod = 0.0f;
		} else if (uv.x > 0.25 + padding) lod = 0.0f;
		if (lod == 2.0f) blur = LODblur(int(lod), offset);
	}
	gl_FragData[0] = vec4(blur, 1.0);
	#endif
}
