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

uniform mat4 shadowProjection;

varying vec2 texcoord;
varying vec3 color;

varying vec4 ndata;

//uniform mat4 shadowProjection;

#define hash(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

#define WAVING_SHADOW

void main() {
	vec4 position = gl_Vertex;
	color = gl_Color.rgb * (gl_TextureMatrix[1] *  gl_MultiTexCoord1).y;

	#ifdef WAVING_SHADOW
	float blockId = mc_Entity.x;
	if (gl_MultiTexCoord0.t < mc_midTexCoord.t && (blockId == 31.0 || blockId == 37.0 || blockId == 38.0)) {
		float rand_ang = hash(position.xz);
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.x += (sin(rand_ang * 10.0 + time + position.y) * 0.2) * (reset * maxStrength);
	}
	position = gl_ProjectionMatrix * (gl_ModelViewMatrix * position);
	#else
	position = ftransform();
	#endif

	float l = sqrt(dot(position.xy, position.xy));

	position.xy /= l * SHADOW_MAP_BIAS + negBias;

	position.z = position.z * 0.5 + 0.25;

	gl_Position = position;
	texcoord = gl_MultiTexCoord0.st;

	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		color = vec3(1.0);
		ndata.a = 0.0;
	}
	ndata.xyz = normalize(mat3(shadowProjection) * (gl_NormalMatrix * gl_Normal)) * 0.5 + 0.5;
	ndata.a = 1.0;
}
