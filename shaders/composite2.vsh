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

flat out vec3 skycolor;
flat out vec3 fogcolor;
flat out vec3 horizontColor;

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
	vec3 suncolor_noon = vec3(2.72, 2.35, 2.1) * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.3, 0.8) * TimeSunset;
	vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.1 * TimeMidnight;

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

	vec3 skycolor_sunrise = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0-rainStrength*1.0) * TimeSunrise;
	vec3 skycolor_noon = vec3(0.16, 0.38, 1.0) * 0.4 * (1.0-rainStrength*1.0) * TimeNoon;
	vec3 skycolor_sunset = vec3(0.5, 0.7, 1.0) * 0.2 * (1.0-rainStrength*1.0) * TimeSunset;
	vec3 skycolor_night = vec3(0.0, 0.0, 0.0) * TimeMidnight;
	vec3 skycolor_rain_day = vec3(1.2, 1.6, 2.0) * 0.1 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	vec3 skycolor_rain_night = vec3(0.0, 0.0, 0.0) * TimeMidnight * rainStrength;
	skycolor = skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night + skycolor_rain_day + skycolor_rain_night;

	vec3 horizontColor_sunrise = vec3(2.52, 1.8, 1.0) * 0.28 * TimeSunrise;
	vec3 horizontColor_noon = vec3(2.0, 2.25, 2.55) * 0.27 * TimeNoon;
	vec3 horizontColor_sunset = vec3(2.52, 1.6, 0.8) * 0.28 * TimeSunset;
	vec3 horizontColor_night = vec3(0.3, 0.7, 1.3) * 0.03 * (1.0-rainStrength*1.0) * TimeMidnight;
	vec3 horizontColor_rain_night = vec3(0.3, 0.7, 1.3) * 0.01 * TimeMidnight * rainStrength;

	horizontColor = horizontColor_sunrise + horizontColor_noon + horizontColor_sunset + horizontColor_night + horizontColor_rain_night;

	vec3 fogclr_sunrise = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunrise * (1.0 - rainStrength * 1.0);
	vec3 fogclr_noon = vec3(0.6, 0.8, 1.27) * 0.5 * TimeNoon * (1.0 - rainStrength * 1.0);
	vec3 fogclr_sunset = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunset * (1.0 - rainStrength * 1.0);
	vec3 fogclr_midnight = vec3(0.2, 0.6, 1.3) * 0.01 * TimeMidnight * (1.0 - rainStrength * 1.0);
	vec3 fogclr_rain_day = vec3(1.5, 1.9, 2.55) * 0.2 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	vec3 fogclr_rain_night = vec3(0.35, 0.7, 1.3) * 0.01  * TimeMidnight * rainStrength;
	fogcolor = fogclr_sunrise + fogclr_noon + fogclr_sunset + fogclr_midnight + fogclr_rain_day + fogclr_rain_night;

	//worldLightPos = normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
}
