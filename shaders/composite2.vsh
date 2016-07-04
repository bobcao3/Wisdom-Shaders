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

out vec4 texcoord;
out float handItemLight;
out float SdotU;
out float MdotU;
out vec3 sunVec;
out vec3 moonVec;
out vec3 upVec;
out vec3 lightPosition;
out float sunVisibility;
out float moonVisibility;
out vec2 screenSunPosition;

uniform int worldTime;
uniform int heldItemId;
uniform float rainStrength;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;

out float TimeSunrise;
out float TimeNoon;
out float TimeSunset;
out float TimeMidnight;

void main() {

	float w_time_f = float(worldTime);

	TimeSunrise  = ((clamp(w_time_f, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(w_time_f, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(w_time_f, 0.0, 2000.0)) / 2000.0) - ((clamp(w_time_f, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(w_time_f, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(w_time_f, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(w_time_f, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(w_time_f, 23000.0, 24000.0) - 23000.0) / 1000.0);

	sunVec = normalize(sunPosition);
	moonVec = normalize(-sunPosition);
	upVec = normalize(upPosition);

	SdotU = dot(sunVec,upVec);
	MdotU = dot(moonVec,upVec);

	sunVisibility = pow(clamp(SdotU+0.1,0.0,0.1)/0.1,2.0);
	moonVisibility = pow(clamp(MdotU+0.1,0.0,0.1)/0.1,2.0);

	lightPosition = normalize(sunPosition);
	vec3 worldSunPosition = normalize((gbufferModelViewInverse * vec4(sunPosition, 0.0)).xyz);
	if (worldSunPosition.y < 0)
		lightPosition *= -1;

	vec4 ndcSunPosition = gbufferProjection * vec4(normalize(lightPosition), 1.0);
	ndcSunPosition /= ndcSunPosition.w;
	screenSunPosition = vec2(-10.0);
	screenSunPosition = ndcSunPosition.xy * 0.5 + 0.5;

	gl_Position = ftransform();

	texcoord = gl_MultiTexCoord0;

}
