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

uniform sampler2D texture;

varying vec4 color;
varying vec2 normal;
varying vec2 texcoord;

/* RENDERTARGETS: 10 */
void main() {
	vec4 weather = texture2D(texture, texcoord) * color;
	float Y = dot(weather.rgb, vec3(0.2126, 0.7152, 0.0722));
	float Cb = (weather.rgb.b - Y) / (2.0 * (1.0 - 0.0722)) + 0.5;
	gl_FragData[0] = vec4(0.0, Y, clamp(Cb, 0.0, 1.0), weather.a);
}
