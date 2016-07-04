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

in vec4 color;
in vec4 texcoord;
in vec4 lmcoord;
in vec2 normal;

uniform sampler2D texture;
uniform sampler2D normals;

void main() {
/* DRAWBUFFERS:024 */
	vec2 adjustedTexCoord = texcoord.st;

	float texinterval = 0.0625f;

	vec3 indlmap = texture2D(texture,adjustedTexCoord).rgb*color.rgb;

	gl_FragData[0] = vec4(indlmap,texture2D(texture,adjustedTexCoord).a*color.a);
	gl_FragData[1] = vec4(normal, 0.0, 1.0);
	gl_FragData[2] = vec4(lmcoord.t, 0.99, lmcoord.s, 1.0);
}
