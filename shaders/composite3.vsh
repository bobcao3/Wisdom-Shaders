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

out vec2 texcoord;
out vec3 worldLightPos;
out vec3 suncolor;

out float TimeSunrise;
out float TimeNoon;
out float TimeSunset;
out float TimeMidnight;

out vec3 fogcolor;

out float extShadow;

#define SUNRISE 23500
#define SUNSET 12000
#define FADE_START 520
#define FADE_END 250

out vec3 skycolor;
out vec3 horizontColor;

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.st;

	TimeSunrise  = ((clamp(wTimeF, 23600.0, 24000.0) - 23600.0) / 400.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23600.0, 24000.0) - 23600.0) / 400.0);

	vec3 suncolor_sunrise = vec3(2.52, 1.4, 0.4) * TimeSunrise;
	vec3 suncolor_noon = vec3(2.52, 2.25, 2.1) * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.3, 0.8) * TimeSunset;
	vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.15 * TimeMidnight;

	suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
	suncolor *= 1.0 - rainStrength * 0.63;

	extShadow = (clamp((wTimeF-12000.0)/300.0,0.0,1.0)-clamp((wTimeF-13000.0)/300.0,0.0,1.0) + clamp((wTimeF-22800.0)/200.0,0.0,1.0)-clamp((wTimeF-23400.0)/200.0,0.0,1.0));

	vec3 skycolor_sunrise = vec3(0.6, 0.56, 0.95) * 0.2 * (1.0-rainStrength*1.0) * TimeSunrise;
	vec3 skycolor_noon = vec3(0.65, 0.64, 1.4) * 0.4 * (1.0-rainStrength*1.0) * TimeNoon;
	vec3 skycolor_sunset = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0-rainStrength*1.0) * TimeSunset;
	vec3 skycolor_night = vec3(0.0, 0.0, 0.0) * TimeMidnight;
	vec3 skycolor_rain_day = vec3(1.2, 1.6, 2.0) * 0.1 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	vec3 skycolor_rain_night = vec3(0.0, 0.0, 0.0) * TimeMidnight * rainStrength;
	skycolor = skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_day + skycolor_rain_night;
	skycolor *= 1.0 - rainStrength * 0.6;

	vec3 horizontColor_sunrise = vec3(2.1, 1.8, 1.0) * 0.28 * TimeSunrise;
	vec3 horizontColor_noon = vec3(2.1, 2.18, 2.16) * 0.27 * TimeNoon;
	vec3 horizontColor_sunset = vec3(2.1, 1.6, 0.8) * 0.28 * TimeSunset;
	vec3 horizontColor_night = vec3(0.3, 0.7, 1.3) * 0.03 * (1.0-rainStrength*1.0) * TimeMidnight;
	vec3 horizontColor_rain_night = vec3(0.3, 0.7, 1.3) * 0.01 * TimeMidnight * rainStrength;

	horizontColor = horizontColor_sunrise + horizontColor_noon + horizontColor_sunset + horizontColor_night + horizontColor_rain_night;
	skycolor *= 1.0 - rainStrength * 0.6;


	worldLightPos = normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 1.0)).xyz);
}
