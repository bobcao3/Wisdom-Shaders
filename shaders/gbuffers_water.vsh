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

varying vec3 wpos;
varying vec2 normal;
varying float iswater;
varying vec2 texcoord;

#include "gbuffers.inc.vsh"

VSH {
	vec4 position;
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		iswater = 0.79f;
		position = gl_ModelViewMatrix * (gl_Vertex - vec4(0.0, 0.2, 0.0, 0.0));
	}	else {
		iswater = 0.95f;
		position = gl_ModelViewMatrix * gl_Vertex;
		//normal = gl_Normal;
	}
	wpos = position.xyz;
	normal = normalEncode(normalize(gl_NormalMatrix * gl_Normal));
	gl_Position = gl_ProjectionMatrix * position;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}
