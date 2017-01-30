/*
 * Copyright 2017 Cheng Cao
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// =============================================================================
//  PLEASE FOLLOW THE LICENSE AND PLEASE DO NOT REMOVE THE LICENSE HEADER
// =============================================================================
//  ANY USE OF THE SHADER ONLINE OR OFFLINE IS CONSIDERED AS INCLUDING THE CODE
//  IF YOU DOWNLOAD THE SHADER, IT MEANS YOU AGREE AND OBSERVE THIS LICENSE
// =============================================================================

#version 130
#pragma optimize(on)

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform vec3 shadowLightPosition;
uniform int worldTime;
uniform float rainStrength;
float wTimeF = float(worldTime);

invariant out vec2 texcoord;
invariant flat out vec3 worldLightPos;
invariant flat out vec3 suncolor;

flat out float TimeSunrise;
flat out float TimeNoon;
flat out float TimeSunset;
flat out float TimeMidnight;

void main() {
	TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	vec3 suncolor_sunrise = vec3(2.52, 1.4, 0.4) * TimeSunrise;
	vec3 suncolor_noon = vec3(2.52, 2.25, 2.1) * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.3, 0.8) * TimeSunset;
	vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.3 * TimeMidnight;

	suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
	suncolor *= 1.0 - rainStrength * 0.63;

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.st;

	worldLightPos = normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 1.0)).xyz);
}
