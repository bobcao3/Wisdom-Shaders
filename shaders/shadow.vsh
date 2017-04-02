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

#pragma optimize(on)

#define SHADOW_MAP_BIAS 0.9
const float negBias = 1.0f - SHADOW_MAP_BIAS;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform float rainStrength;
uniform float frameTimeCounter;

varying vec3 coords;
varying vec3 color;

#define texcoord coords.xy
#define iswater coords.z

#define hash(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

//#define WAVING_SHADOW

void main() {
	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	color = gl_Color.rgb;

	if (blockId == 31.0 || blockId == 37.0 || blockId == 38.0 && gl_MultiTexCoord0.t < mc_midTexCoord.t) {
		float rand_ang = hash(position.xz);
		position.x += rand_ang * 0.2;
		position.z -= rand_ang * 0.2;
		#ifdef WAVING_SHADOW
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			float reset = cos(rand_ang * 10.0 + time * 0.1);
			reset = max( reset * reset, max(rainStrength, 0.1));
			position.x += sin(rand_ang * 10.0 + time + position.y) * 0.2 * reset * maxStrength;
			position.z += sin(rand_ang * 10.0 + time - position.y) * 0.2 * reset * maxStrength;
		}
		#endif
	}

	iswater = float(blockId == 8.0 || blockId == 9.0);

	gl_Position = gl_ProjectionMatrix * (gl_ModelViewMatrix * position);

	float distortFactor = negBias + length(gl_Position.xy) * SHADOW_MAP_BIAS;
	gl_Position.xy /= distortFactor;
	texcoord = gl_MultiTexCoord0.st;
}
