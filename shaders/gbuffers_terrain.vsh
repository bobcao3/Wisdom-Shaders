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


#define NORMALS

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

#include "Animation.glsl"

varying f16vec4 color;
varying vec4 coords;
varying vec4 wdata;

varying float dis;

#define normal wdata.xyz
#define flag wdata.w

#define texcoord coords.rg
#define lmcoord coords.ba

#ifdef NORMALS
varying f16vec3 tangent;
varying f16vec3 binormal;
#else
f16vec3 tangent;
f16vec3 binormal;

f16vec2 normalEncode(f16vec3 n) {return sqrt(-n.z*0.125f+0.125f) * normalize(n.xy) + 0.5f;}
varying vec2 n2;
#endif

#define ParallaxOcclusion
#ifdef ParallaxOcclusion
varying f16vec3 tangentpos;
#endif

#define WAVING_FOILAGE

#define hash(p) fract(mod(p.x, 1.0) * 73758.23f - p.y)

void main() {
	color = gl_Color;
	
	normal = normalize(gl_NormalMatrix * normalize(gl_Normal));

	tangent = normalize(gl_NormalMatrix * normalize(at_tangent.xyz));
    binormal = normalize(cross(tangent, normal)) * sign(at_tangent.w);

	vec4 position = gl_Vertex;
	vec3 animation_position = (gbufferModelViewInverse * gl_ModelViewMatrix * position).xyz + cameraPosition;
	animation_position = floor(animation_position * 64.0 + 0.5) / 64.0;
	float blockId = mc_Entity.x;
	flag = 0.7;

	#ifdef WAVING_FOILAGE
	float maxStrength = 1.0 + rainStrength * 0.5;
	float time = animationPhase(1720.0);
	#endif

	if (blockId == 31.0 || blockId == 37.0 || blockId == 38.0 || blockId == 59.0 || blockId == 141.0 || blockId == 142.0) {
		#ifdef WAVING_FOILAGE
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			float rand_ang = hash(animation_position.xz);
			float reset = cos(rand_ang * 10.0 + time * 0.1);
			reset = max( reset * reset, max(rainStrength, 0.1));
			position.x += (sin(rand_ang * 10.0 + time + animation_position.y) * 0.2) * (reset * maxStrength);
		}
		#endif
		flag = 0.50;
	} else if(mc_Entity.x == 18.0 || mc_Entity.x == 106.0 || mc_Entity.x == 161.0 || mc_Entity.x == 175.0) {
		#ifdef WAVING_FOILAGE
		float rand_ang = hash(animation_position.xz);
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.xyz += (sin(rand_ang * 5.0 + time + animation_position.y) * 0.035 + 0.035) * (reset * maxStrength) * tangent;
		#endif
		flag = 0.50;
	} else if (blockId == 83.0 || blockId == 39 || blockId == 40 || blockId == 6.0 || blockId == 104 || blockId == 105 || blockId == 115) flag = 0.51;

	position = gl_ModelViewMatrix * position;
	vec3 wpos = position.xyz;
	gl_Position = gl_ProjectionMatrix * position;
	texcoord = gl_MultiTexCoord0.st;
	lmcoord = (gl_TextureMatrix[1] *  gl_MultiTexCoord1).xy;

	#ifdef ParallaxOcclusion
	f16mat3 TBN = f16mat3(tangent, binormal, normal);
	tangentpos = normalize(wpos * TBN);
	#endif
	
	#ifndef NORMALS
	n2 = normalEncode(normal);
	#endif
	
	dis = length(wpos);
}
