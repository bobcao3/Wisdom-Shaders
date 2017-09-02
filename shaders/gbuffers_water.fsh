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

varying vec2 normal;
varying vec4 coords;

#define texcoord coords.rg
#define skyLight coords.b
#define iswater coords.a

/* DRAWBUFFERS:71 */
void main() {
	vec4 color = vec4(0.0);
	if (iswater > 0.78f && iswater < 0.8f)
		color = vec4(vec3(0.0537,0.3562,0.5097) * skyLight * 0.2, 1.0);
	else
		color = texture2D(tex, texcoord);
	
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(normal, iswater, 1.0);
}
