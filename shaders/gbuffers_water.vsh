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

	#define WAVING_WATER

const float PI = 3.141593;

out vec4 color;
out vec4 texcoord;
out vec4 lmcoord;
out vec4 position;
out vec3 binormal;
out vec2 normal;
out vec3 tangent;
out vec3 viewVector;
out vec3 wpos;
out float iswater;
out float waveh;

attribute vec4 mc_Entity;

uniform vec3 cameraPosition;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform int worldTime;
uniform float frameTimeCounter;
uniform int isEyeInWater;

vec2 normalEncode(vec3 n) {
    vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
    enc = enc*0.5+0.5;
    return enc;
}

void main() {

	//vec4 viewpos = gl_ModelViewMatrix * gl_Vertex;
	position = gl_ModelViewMatrix * gl_Vertex;
	iswater = 0.0f;
	float displacement = 0.0;

	/* un-rotate */
	vec4 viewpos = gbufferModelViewInverse * position;

	vec3 worldpos = viewpos.xyz + cameraPosition;
	wpos = worldpos;

	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {

		iswater = 1.0;
		float fy = fract(worldpos.y + 0.001);

		#ifdef WAVING_WATER

			float wave = 0.06 * sin(2 * PI * (frameTimeCounter*0.55 + worldpos.x /  1.0 + worldpos.z / 3.0))
						+ 0.09 * sin(2 * PI * (frameTimeCounter*0.4 + worldpos.x / 11.0 - worldpos.z /  5.0)) + 0.09 * sin(2 * PI * (frameTimeCounter*0.4 - worldpos.x / 16.0 + worldpos.z /  10.0)) - 0.1;
			displacement = clamp(wave, -fy, 1.0-fy);
			viewpos.y += displacement;

			waveh = displacement;
		#endif

	}

	/* re-rotate */
	viewpos = gbufferModelView * viewpos;

	/* projectify */
	gl_Position = gl_ProjectionMatrix * viewpos;

	color = gl_Color;

	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;

	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;

	gl_FogFragCoord = gl_Position.z;

	normal = normalEncode(gl_NormalMatrix * gl_Normal);
}
