#version 130
#pragma optimize(on)

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform int worldTime;
uniform float rainStrength;
float wTimeF = float(worldTime);

out vec2 texcoord;
flat out vec3 suncolor;

flat out float TimeSunrise;
flat out float TimeNoon;
flat out float TimeSunset;
flat out float TimeMidnight;
flat out float extShadow;

#define SUNRISE 23200
#define SUNSET 12800
#define FADE_START 500
#define FADE_END 250

void main() {
	TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	vec3 suncolor_sunrise = vec3(2.52, 1.4, 0.4) * TimeSunrise;
	vec3 suncolor_noon = vec3(2.52, 2.25, 2.1) * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.3, 0.8) * TimeSunset;
	vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.15 * TimeMidnight;

	suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
	suncolor *= 1.0 - rainStrength * 0.83;

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.st;

	if(worldTime >= SUNRISE - FADE_START && worldTime <= SUNRISE + FADE_START) {
		extShadow = 1.0;
		if(worldTime < SUNRISE - FADE_END) extShadow -= float(SUNRISE - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNRISE + FADE_END)
			extShadow -= float(worldTime - SUNRISE - FADE_END) / float(FADE_END);
	} else if(worldTime >= SUNSET - FADE_START && worldTime <= SUNSET + FADE_START) {
		extShadow = 1.0;
		if(worldTime < SUNSET - FADE_END) extShadow -= float(SUNSET - FADE_END - worldTime) / float(FADE_END); else if(worldTime > SUNSET + FADE_END)
			extShadow -= float(worldTime - SUNSET - FADE_END) / float(FADE_END);
	} else
		extShadow = 0.0;

	//worldLightPos = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
}
