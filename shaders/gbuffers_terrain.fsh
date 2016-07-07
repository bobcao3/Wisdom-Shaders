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

const int noiseTextureResolution = 256;

uniform int fogMode;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D specular;

in vec4 color;
in vec4 texcoord;
in vec4 lmcoord;
in vec2 normal;
in float entities;
in float iswater;

/* DRAWBUFFERS:0246 */
void main() {
	vec4 texcolor = texture2D(texture, texcoord.st);

	gl_FragData[0] = texcolor * texture2D(lightmap, lmcoord.st) * color;
	gl_FragData[1] = vec4(normal, 0.0, 1.0);
	gl_FragData[2] = vec4(lmcoord.t, entities, lmcoord.s, 1.0);
	gl_FragData[3] = vec4(texture2D(specular, texcoord.st).rgb, texcolor.a);
}
