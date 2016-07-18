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

uniform sampler2D tex;

in vec4 texcoord;
flat in lowp float discard_flag;

void main() {

	vec4 texcolor = texture2D(tex, texcoord.st);

	if (texcolor.a < 0.1 || discard_flag == 1) discard;

	if (discard_flag == 0.5)
		gl_FragData[0] = vec4(texcolor.rgb, discard_flag);
	else
		gl_FragData[0] = texcolor;
	//gl_FragData[]
}
