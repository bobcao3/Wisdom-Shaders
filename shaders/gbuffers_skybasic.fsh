// Copyright 2016 bobcao3 <bobcaocheng@163.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#version 130

uniform int fogMode;
uniform vec3 skyColor;

in vec4 color;
in vec2 normal;
in vec4 lmcoord;

/* DRAWBUFFERS:024 */
void main() {

	vec3 skyColor = mix(gl_Fog.color.rgb, skyColor, 0.9);

	gl_FragData[0] = vec4(skyColor, color.a);
	gl_FragData[1] = vec4(normal, 0.0, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
}
