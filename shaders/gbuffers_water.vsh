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
varying float skyLight;

#include "gbuffers.inc.vsh"

#ifdef NOSHADOW
float getwave(vec3 worldpos) {return 0.06 * sin(2 * PI * (frameTimeCounter*0.55 + worldpos.x /  1.0 + worldpos.z / 3.0)) + 0.06 * sin(2 * PI * (frameTimeCounter*0.4 + worldpos.x / 11.0 + worldpos.z /  5.0));}
#endif

VSH {
	vec4 position;
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		iswater = 0.79f;

		#ifdef NOSHADOW
		vec4 viewpos = gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex);
		vec3 worldpos = viewpos.xyz + cameraPosition;
		position = gl_ModelViewMatrix * (gl_Vertex - vec4(0.0, getwave(worldpos) + 0.2, 0.0, 0.0));
		#else
		position = gl_ModelViewMatrix * (gl_Vertex - float(mc_Entity.x == 8.0) * vec4(0.0, 0.1, 0.0, 0.0));
		#endif
	}	else {
		iswater = 0.95f;
		position = gl_ModelViewMatrix * gl_Vertex;
		//normal = gl_Normal;
	}
	wpos = position.xyz;
	normal = normalEncode(normalize(gl_NormalMatrix * gl_Normal));
	gl_Position = gl_ProjectionMatrix * position;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	skyLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).y;
}
