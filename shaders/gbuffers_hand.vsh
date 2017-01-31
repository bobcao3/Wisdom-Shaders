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

#version 130
#extension GL_ARB_shading_language_420pack : require
#pragma optimize(on)

uniform mat4 gbufferModelViewInverse;

out  vec4 color;
flat out vec2 normal;
out  vec2 texcoord;
out  vec3 wpos;
out  vec2 lmcoord;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	gl_Position = gl_ModelViewMatrix * gl_Vertex;
	wpos = gl_Position.xyz;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	normal = normalEncode(normalize(gl_NormalMatrix * gl_Normal));
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
}
