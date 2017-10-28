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

uniform sampler2D tex;

varying vec4 data;
varying vec2 uv;
varying vec3 uv1;

#include "libs/uniforms.glsl"
#include "libs/encoding.glsl"
#include "libs/color.glsl"

/* DRAWBUFFERS:5 */
void main() {
	vec4 color = vec4(0.0);
	if (maskFlag(data.b, waterFlag)) {
		color = texture2D(gaux3, uv1.st);

		color = vec4(mix(color.rgb, vec3(0.0537,0.3562,0.5097), 0.2), 1.0);
	} else {
		color = texture2D(tex, uv);
		color = fromGamma(color);
	}

	gl_FragData[0] = color;
}
