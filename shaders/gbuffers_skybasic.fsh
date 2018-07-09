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
#include "libs/compat.glsl"
#pragma optimize(on)

#include "libs/encoding.glsl"

varying vec4 color;

float luma(vec3 c) {
  return dot(c,vec3(0.2126, 0.7152, 0.0722));
}

/* DRAWBUFFERS:04 */
void main() {
	float saturation = abs(color.r - color.g) + abs(color.r - color.b) + abs(color.g - color.b);
	float luma = dot(color.rgb,vec3(0.2126, 0.7152, 0.0722));

	gl_FragData[0] = (saturation > 0.01 || luma < 0.1) ? vec4(0.0,0.0,0.0,1.0) : color * min(1.0, luma * 2.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
}
