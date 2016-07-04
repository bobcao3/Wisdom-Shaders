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

	#define SHADOW_MAP_BIAS 0.8

	#define WAVING_TERRAIN

const float PI = 3.141593;

out vec4 texcoord;
out float discard_flag;
out float depth;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform vec3 cameraPosition;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

void main() {
	discard_flag = 0;
	if (mc_Entity.x == 8 || mc_Entity.x == 9 || mc_Entity.x == 160.0f || mc_Entity.x == 95.0f || mc_Entity.x == 51.0f) discard_flag = 1;
		//water
		//stained glass pane
		//stained glass
		//Fire

	gl_Position = ftransform();

	float dist = length(gl_Position.xy);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	gl_Position.xy /= distortFactor;

	texcoord = gl_MultiTexCoord0;

	depth = gl_Position.y;

	gl_FrontColor = gl_Color;
}
