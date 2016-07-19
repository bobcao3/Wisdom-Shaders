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
#pragma optimize(on)

out vec4 texcoord;
out vec3 lightPosition;
flat out vec2 screenSunPosition;
out float is_towords_sun;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;

void main() {
	lightPosition = normalize(sunPosition);
	vec3 worldSunPosition = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
	if (worldSunPosition.y < 0)
		lightPosition *= -1;

	//is_towords_sun = dot(lightPosition.xyz, worldPosition.xyz);

	vec4 ndcSunPosition = gbufferProjection * vec4(normalize(lightPosition), 1.0);
	ndcSunPosition /= ndcSunPosition.w;
	screenSunPosition = ndcSunPosition.xy * 0.5 + 0.5;

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
}
