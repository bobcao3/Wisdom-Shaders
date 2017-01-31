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

out lowp vec4 color;
flat out vec2 normal;
out highp vec2 texcoord;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	gl_Position = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	normal = normalEncode(gl_NormalMatrix * vec3(0.0, 1.0, 0.0));
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}
