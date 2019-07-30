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

attribute vec4 mc_Entity;

uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

const float PI = 3.14159f;

varying vec2 normal;
varying vec4 coords;

uniform bool isEyeInWater;

#define texcoord coords.rg
#define skyLight coords.b
#define iswater coords.a

#include "gbuffers.inc.vsh"

VSH {
	iswater = 0.95f;
	vec4 pos = gl_Vertex;
#if MC_VERSION >= 11300
	if (mc_Entity.y == 0.0) {
#else
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
#endif
		iswater = 0.79f;
		pos.y += float(isEyeInWater) * 0.3 - 0.2;
	}
	pos = gl_ModelViewMatrix * pos;
	gl_Position = gl_ProjectionMatrix * pos;
	
	normal = normalEncode(gl_NormalMatrix * gl_Normal);
	
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	skyLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).y;
}
