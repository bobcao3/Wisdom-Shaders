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

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

//flat in vec2 normal;
in vec3 wpos;
flat in  float iswater;
in vec2 texcoord;
flat in vec2 normal;

#define PBR

/* DRAWBUFFERS:0346 */
void main() {
	if (iswater < 0.90f) {
		gl_FragData[0] = vec4(0.2, 0.2, 0.4, 0.18);

		#ifdef PBR
		gl_FragData[2] = vec4(0.2, 0.99, 0.0, 1.0);
		#else
		gl_FragData[2] = vec4(0.8, 0.0, 0.0, 1.0);
		#endif
	}	else {
		gl_FragData[0] = texture2D(texture, texcoord);

		#ifdef PBR
		gl_FragData[2] = vec4(0.01, 0.99, 0.0, 1.0);
		#else
		gl_FragData[2] = vec4(0.8, 0.0, 0.0, 1.0);
		#endif
	}
	gl_FragData[1] = vec4(normal, iswater, 1.0);

	gl_FragData[3] = vec4(wpos, 1.0);
}
