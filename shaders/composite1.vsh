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

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int worldTime;
uniform int heldItemId;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;

out vec4 texcoord;
out vec3 lightPosition;
out vec3 worldSunPosition;
out float SdotU;
out float MdotU;
out vec3 sunVec;
out vec3 moonVec;
out vec3 upVec;
out float moonVisibility;
out float extShadow;
out float handlight;

#define SUNRISE 23200.0
#define SUNSET 12800.0
#define FADE_START 500.0
#define FADE_END 250.0

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
	if(worldTime >= SUNRISE - FADE_START && worldTime <= SUNRISE + FADE_START)
	{
		extShadow = 1.0;
		if(worldTime < SUNRISE - FADE_END) extShadow -= float(SUNRISE - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNRISE + FADE_END)
			extShadow -= float(worldTime - SUNRISE - FADE_END) / float(FADE_END);
	}
	else if(worldTime >= SUNSET - FADE_START && worldTime <= SUNSET + FADE_START)
	{
		extShadow = 1.0;
		if(worldTime < SUNSET - FADE_END) extShadow -= float(SUNSET - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNSET + FADE_END)
			extShadow -= float(worldTime - SUNSET - FADE_END) / float(FADE_END);
	}
	else
		extShadow = 0.0;

	lightPosition = normalize(sunPosition);
	worldSunPosition = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
	if (worldSunPosition.y < 0)
		lightPosition *= -1;

	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);

	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);

	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);

	handlight = 0.0;
	if (heldItemId == 50) {
		// torch
		handlight = 0.5;
	} else if (heldItemId == 76 || heldItemId == 94) {
		// active redstone torch / redstone repeater
		handlight = 0.1;
	} else if (heldItemId == 89) {
		// lightstone
		handlight = 0.6;
	} else if (heldItemId == 10 || heldItemId == 11 || heldItemId == 51) {
		// lava / lava / fire
		handlight = 0.5;
	} else if (heldItemId == 91) {
		// jack-o-lantern
		handlight = 0.6;
	} else if (heldItemId == 327) {
		handlight = 0.2;
	}
}
