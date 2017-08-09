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

// =============================================================================
//  PLEASE FOLLOW THE LICENSE AND PLEASE DO NOT REMOVE THE LICENSE HEADER
// =============================================================================
//  ANY USE OF THE SHADER ONLINE OR OFFLINE IS CONSIDERED AS INCLUDING THE CODE
//  IF YOU DOWNLOAD THE SHADER, IT MEANS YOU AGREE AND OBSERVE THIS LICENSE
// =============================================================================

#version 120
#include "compat.glsl"

#pragma optimize(on)

varying vec2 texcoord;

uniform sampler2D composite;

#define BLOOM
//#define DOF

uniform float viewWidth;
uniform float viewHeight;

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}

#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))

float bayer_4x4(in vec2 pos, in vec2 view) {
	return bayer4(pos * view);
}

#if (defined(BLOOM) || defined(DOF))
const float padding = 0.02f;
const bool compositeMipmapEnabled = true;

bool checkBlur(vec2 offset, float scale) {
	return
	(  (texcoord.s - offset.s + padding < 1.0f / scale + (padding * 2.0f))
	&& (texcoord.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)) );
}

const float weight[3] = float[] (0.2750, 0.4357, 0.2750);

vec3 LODblur(in int LOD, in vec2 offset) {
	float scale = exp2(LOD);
	vec3 bloom = vec3(0.0);

	float allWeights = 0.0f;
	float d1 = bayer_4x4(texcoord, vec2(viewWidth, viewHeight)) - 1.0;
	float d2 = bayer_4x4(texcoord, vec2(viewWidth, viewHeight)) - 1.0;

	for (int i = 0; i < 3; i++) {
		for (int j = 0; j < 3; j++) {
			vec2 coord = vec2(i * 2.0 + d1, j * 2.0 + d2) / vec2(viewWidth, viewHeight);

			vec2 finalCoord = (texcoord.st + coord.st - offset.st) * scale;

			bloom += clamp(texture2D(composite, finalCoord).rgb, vec3(0.0f), vec3(1.0f)) * weight[i] * weight[j];
		}
	}

	return bloom;
}
#endif

/* DRAWBUFFERS:0 */
void main() {
	#if (defined(BLOOM) || defined(DOF))
	vec3 blur = vec3(0.0);
	/* LOD 2 */
	float lod = 2.0; vec2 offset = vec2(0.0f);
	if (texcoord.y < 0.25 + padding * 2.0 + 0.6251 && texcoord.x < 0.0078125 + 0.25f + 0.100f) {
		if (texcoord.y > 0.25 + padding) {
			     if (checkBlur(offset = vec2(0.0f, 0.35f)     + vec2(0.000f, 0.035f), exp2(lod = 3.0))) { /* LOD 3 */ }
			else if (checkBlur(offset = vec2(0.125f, 0.35f)   + vec2(0.030f, 0.035f), exp2(lod = 4.0))) { /* LOD 4 */ }
			else if (checkBlur(offset = vec2(0.1875f, 0.35f)  + vec2(0.060f, 0.035f), exp2(lod = 5.0))) { /* LOD 5 */ }
			else if (checkBlur(offset = vec2(0.21875f, 0.35f) + vec2(0.090f, 0.035f), exp2(lod = 6.0))) { /* LOD 6 */ }
			else lod = 0.0f;
		} else if (texcoord.x > 0.25 + padding) lod = 0.0f;
		if (lod > 1.0f) blur = LODblur(int(lod), offset);
	}
	gl_FragData[0] = vec4(blur, 1.0);
	#endif
}
