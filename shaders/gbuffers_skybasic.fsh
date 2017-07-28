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

uniform vec3 skyColor;
//varying vec4 color;

const vec3 wavelengthRGB = vec3(0.7, 0.5461, 0.4358);
const vec3 skyOriginalRGB = vec3(1.0) / pow(wavelengthRGB, vec3(4.0));
const vec3 skyRGB = skyOriginalRGB / skyOriginalRGB.b * 1.5;

float luma(in vec3 color) { return dot(color,vec3(0.2126, 0.7152, 0.0722)); }

/* DRAWBUFFERS:02 */
void main() {
	gl_FragData[0] = vec4(luma(skyColor) * skyRGB, 1.0);
	gl_FragData[1] = vec4(0.0, 0.0, 0.2, 1.0);
}
