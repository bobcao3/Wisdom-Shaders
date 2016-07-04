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
in float depth;
in float discard_flag;

void main() {

	if (discard_flag == 1) discard;

	gl_FragData[0] = vec4(depth, texture2D(tex, texcoord.st).gba);
	//gl_FragData[]
}
