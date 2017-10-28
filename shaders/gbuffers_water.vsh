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

varying vec4 data;
varying vec2 uv;
varying vec3 uv1;

uniform mat4 gbufferProjection;

#include "libs/encoding.glsl"

void main() {
	data.b = (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) ? waterFlag : transparentFlag;

	vec4 pos = gl_Vertex;
	pos = gl_ModelViewMatrix * pos;
	gl_Position = gl_ProjectionMatrix * pos;

	//normal = normalEncode(gl_NormalMatrix * gl_Normal);

	uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	//skyLight = (gl_TextureMatrix[1] * gl_MultiTexCoord1).y;

	vec4 clip = gbufferProjection * pos;
	clip /= clip.w;
	uv1 = clip.xyz * 0.5 + 0.5;
}
