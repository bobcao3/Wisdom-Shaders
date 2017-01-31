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

//#version 440 compatibility
#version 130

#extension GL_ARB_separate_shader_objects : require
#extension GL_ARB_shader_texture_lod : require
#pragma optimize(on)

#define NORMALS

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelViewInverse;
uniform float rainStrength;
uniform float frameTimeCounter;

layout(location = 0) out lowp vec4 color;
layout(location = 1) out lowp vec3 normal;
layout(location = 2) out highp vec2 texcoord;
layout(location = 3) out highp vec3 wpos;
layout(location = 4) out lowp vec2 lmcoord;
layout(location = 5) out float flag;

#ifdef NORMALS
layout(location = 6) out vec3 tangent;
layout(location = 7) out vec3 binormal;
#else
vec3 tangent;
vec3 binormal;
#endif

//#define ParallaxOcculusion
/*#ifdef ParallaxOcculusion
out vec2 midTexCoord;
out vec3 TangentFragPos;
out vec4 vtexcoordam;
#endif*/

#include "gbuffers.inc.vsh"

#define hash(p) fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123)

/*float noise( in vec2 p ) {
	vec2 i = floor( p );
	vec2 f = fract( p );
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0+2.0*mix( mix( hash( i + vec2(0.0,0.0) ),
	hash( i + vec2(1.0,0.0) ), u.x),
	mix( hash( i + vec2(0.0,1.0) ),
	hash( i + vec2(1.0,1.0) ), u.x), u.y);
}*/

VSH {
	color = gl_Color;

	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = gl_NormalMatrix * vec3( 0.0,  0.0, -1.0);
		binormal = gl_NormalMatrix * vec3( 0.0, -1.0,  0.0);
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = gl_NormalMatrix * vec3( 0.0,  0.0,  1.0);
		binormal = gl_NormalMatrix * vec3( 0.0, -1.0,  0.0);
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = gl_NormalMatrix * vec3( 1.0,  0.0,  0.0);
		binormal = gl_NormalMatrix * vec3( 0.0,  0.0,  1.0);
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = gl_NormalMatrix * vec3( 1.0,  0.0,  0.0);
		binormal = gl_NormalMatrix * vec3( 0.0,  0.0,  1.0);
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = gl_NormalMatrix * vec3( 1.0,  0.0,  0.0);
		binormal = gl_NormalMatrix * vec3( 0.0, -1.0,  0.0);
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = gl_NormalMatrix * vec3(-1.0,  0.0,  0.0);
		binormal = gl_NormalMatrix * vec3( 0.0, -1.0,  0.0);
	}

	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	flag = 0.7;
	if (blockId == 31.0 || blockId == 37.0 || blockId == 38.0) {
		float rand_ang = hash(position.xz) * 0.3 * 3.14159f;
		position.x += sin(rand_ang) * 0.2;
		position.z += cos(rand_ang) * 0.2;
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			float blockId = mc_Entity.x;
			float maxStrength = 1.0 + rainStrength * 0.5;
			float time = frameTimeCounter * 3.0;
			float reset = cos(hash(position.xy) * 10.0 + time * 0.1);
			reset = max( reset * reset, max(rainStrength, 0.1));
			position.x += sin(hash(position.xz) * 10.0 + time) * 0.2 * reset * maxStrength;
			position.z += sin(hash(position.yz) * 10.0 + time) * 0.2 * reset * maxStrength;
		}

		flag = 0.50;
	} else if(mc_Entity.x == 18.0 || mc_Entity.x == 106.0 || mc_Entity.x == 161.0 || mc_Entity.x == 175.0) {
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(hash(position.xy) * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.xyz += tangent * sin(hash(gl_Vertex.xz) * 5.0 + time) * 0.07 * reset * maxStrength;
		position.xyz += binormal * sin(hash(gl_Vertex.yz) * 5.0 + time) * 0.07 * reset * maxStrength;

		flag = 0.50;
	} else if (blockId == 83.0 || blockId == 39 || blockId == 40 || blockId == 6.0 || blockId == 104 || blockId == 105 || blockId == 115 || blockId == 59 || blockId == 141 || blockId == 142) {
		flag = 0.51;
	}

	gl_Position = gl_ModelViewMatrix * position;
	wpos = gl_Position.xyz;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	//#ifdef NORMALS
	normal = normalize(gl_NormalMatrix * gl_Normal);
	//#else
	//normal = normalize(gl_NormalMatrix * gl_Normal);
	//#endif
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	/*
	#ifdef ParallaxOcculusion
	midTexCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord - midTexCoord;
	vtexcoordam.pq  = abs(texcoordminusmid) * 2;
	vtexcoordam.st  = min(texcoord, midTexCoord - texcoordminusmid);
	mat3 TBN = mat3(
		tangent.x, binormal.x, normal.x,
		tangent.y, binormal.y, normal.y,
		tangent.z, binormal.z, normal.z);
	TangentFragPos  = normalize(TBN * (wpos.xyz - vec3(0.0, 1.67, 0.0)));
	#endif*/
}
