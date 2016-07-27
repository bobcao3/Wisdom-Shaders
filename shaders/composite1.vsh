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

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform int worldTime;
uniform int heldItemId;
uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse;
uniform float wetness;

out vec4 texcoord;
flat out vec3 lightPosition;
flat out vec3 worldSunPosition;
flat out vec3 suncolor;
out float SdotU;
out float MdotU;
out vec3 sunVec;
out vec3 moonVec;
out vec3 upVec;
flat out vec3 skyColorC;
flat out float moonVisibility;
flat out float extShadow;
flat out float handlight;

invariant flat out float TimeSunrise;
invariant flat out float TimeNoon;
invariant flat out float TimeSunset;
invariant flat out float TimeMidnight;

#define SUNRISE 23200.0
#define SUNSET 12800.0
#define FADE_START 500.0
#define FADE_END 250.0

vec3 rgbToHsl(vec3 rgbColor) {
    rgbColor = clamp(rgbColor, vec3(0.0), vec3(1.0));
    float h, s, l;
    float r = rgbColor.r, g = rgbColor.g, b = rgbColor.b;
    float minval = min(r, min(g, b));
    float maxval = max(r, max(g, b));
    float delta = maxval - minval;
    l = ( maxval + minval ) / 2.0;
    if (delta == 0.0)
    {
        h = 0.0;
        s = 0.0;
    }
    else
    {
        if ( l < 0.5 )
            s = delta / ( maxval + minval );
        else
            s = delta / ( 2.0 - maxval - minval );

        float deltaR = (((maxval - r) / 6.0) + (delta / 2.0)) / delta;
        float deltaG = (((maxval - g) / 6.0) + (delta / 2.0)) / delta;
        float deltaB = (((maxval - b) / 6.0) + (delta / 2.0)) / delta;

        if(r == maxval)
            h = deltaB - deltaG;
        else if(g == maxval)
            h = ( 1.0 / 3.0 ) + deltaR - deltaB;
        else if(b == maxval)
            h = ( 2.0 / 3.0 ) + deltaG - deltaR;

        if ( h < 0.0 )
            h += 1.0;
        if ( h > 1.0 )
            h -= 1.0;
    }
    return vec3(h, s, l);
}

float hueToRgb(float v1, float v2, float vH) {
    if (vH < 0.0)
        vH += 1.0;
    if (vH > 1.0)
        vH -= 1.0;
    if ((6.0 * vH) < 1.0)
        return (v1 + (v2 - v1) * 6.0 * vH);
    if ((2.0 * vH) < 1.0)
        return v2;
    if ((3.0 * vH) < 2.0)
        return (v1 + ( v2 - v1 ) * ( ( 2.0 / 3.0 ) - vH ) * 6.0);
    return v1;
}

vec3 hslToRgb(vec3 hslColor) {
    hslColor = clamp(hslColor, vec3(0.0), vec3(1.0));
    float r, g, b;
    float h = hslColor.r, s = hslColor.g, l = hslColor.b;
    if (s == 0.0)
    {
        r = l;
        g = l;
        b = l;
    }
    else
    {
        float v1, v2;
        if (l < 0.5)
            v2 = l * (1.0 + s);
        else
            v2 = (l + s) - (s * l);

        v1 = 2.0 * l - v2;

        r = hueToRgb(v1, v2, h + (1.0 / 3.0));
        g = hueToRgb(v1, v2, h);
        b = hueToRgb(v1, v2, h - (1.0 / 3.0));
    }
    return vec3(r, g, b);
}

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

	float rainStrength2 = clamp(wetness, 0.0f, 1.0f) / 1.0f;

	float timefract = worldTime;
	TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(timefract, 0.0, 2000.0)) / 2000.0) - ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);


	vec3 suncolor_sunrise = vec3(1.52, 1.2, 0.9) * TimeSunrise;
  vec3 suncolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon;
  vec3 suncolor_sunset = vec3(1.52, 1.0, 0.7) * TimeSunset;
  vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.37 * TimeMidnight * (1.0 - rainStrength2 * 1.0);

  suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
  suncolor.r = pow(suncolor.r, 1.0 - rainStrength2 * 0.5);
  suncolor.g = pow(suncolor.g, 1.0 - rainStrength2 * 0.5);
  suncolor.b = pow(suncolor.b, 1.0 - rainStrength2 * 0.5);

	vec3 skycolor_sunrise = vec3(1.52, 1.2, 0.9) * TimeSunrise;
  vec3 skycolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon;
  vec3 skycolor_sunset = vec3(1.52, 1.0, 0.7) * TimeSunset;
  vec3 skycolor_midnight = vec3(0.3, 0.7, 1.3) * 0.37 * TimeMidnight * (1.0 - rainStrength2 * 1.0);

  skyColorC = skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_midnight;
  skyColorC = rgbToHsl(skyColorC);
	skyColorC.r = pow(skyColorC.r, 1 - wetness * 0.5);
	skyColorC.g = skyColorC.g * (1 - wetness * 0.75);
	skyColorC = hslToRgb(skyColorC);
  skyColorC *= (1 - wetness * 0.85);

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
