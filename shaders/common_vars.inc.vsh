uniform int worldTime;
uniform float rainStrength;

varying vec2 texcoord;
varying vec3 suncolor;

varying float TimeSunrise;
varying float TimeNoon;
varying float TimeSunset;
varying float TimeMidnight;
varying float extShadow;

varying vec3 skycolor;
varying vec3 fogcolor;
varying vec3 horizontColor;
varying vec3 totalSkyLight;

#define SUNRISE 23500
#define SUNSET 12000
#define FADE_START 520
#define FADE_END 350

float wTimeF;

void calcCommon() {
	wTimeF = float(worldTime);

	TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	vec3 suncolor_sunrise = vec3(2.52, 1.4, 0.4) * TimeSunrise;
	vec3 suncolor_noon = vec3(2.72, 2.35, 2.1) * 0.7 * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.3, 0.8) * 0.85 * TimeSunset;
	vec3 suncolor_midnight = vec3(0.14, 0.5, 0.9) * 0.04 * TimeMidnight;

	suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
	suncolor *= 1.0 - rainStrength * 0.93;

	extShadow = (clamp((wTimeF-12000.0)/300.0,0.0,1.0)-clamp((wTimeF-13000.0)/300.0,0.0,1.0) + clamp((wTimeF-22800.0)/200.0,0.0,1.0)-clamp((wTimeF-23400.0)/200.0,0.0,1.0));

	vec3 skycolor_sunrise = vec3(0.6, 0.56, 0.95) * 0.2 * TimeSunrise;
	vec3 skycolor_noon = vec3(0.45, 0.61, 1.0) * 0.9 * TimeNoon;
	vec3 skycolor_sunset = vec3(0.5, 0.7, 1.0) * 0.2 * TimeSunset;
	vec3 skycolor_night = vec3(0.0, 0.0, 0.0) * TimeMidnight;
	skycolor = skycolor_sunrise + skycolor_noon + skycolor_sunset + skycolor_night;
	skycolor *= 1.0 - rainStrength * 0.83;

	vec3 horizontColor_sunrise = vec3(2.1, 1.8, 1.0) * 0.28 * TimeSunrise;
	vec3 horizontColor_noon = vec3(2.1, 2.18, 2.16) * 0.27 * TimeNoon;
	vec3 horizontColor_sunset = vec3(2.1, 1.6, 0.8) * 0.28 * TimeSunset;
	vec3 horizontColor_night = vec3(0.3, 0.7, 1.3) * 0.1 * TimeMidnight;

	horizontColor = horizontColor_sunrise + horizontColor_noon + horizontColor_sunset + horizontColor_night;
	horizontColor *= 1.0 - rainStrength * 0.53;
	
	totalSkyLight = mix(vec3(0.168, 0.35, 1.4), vec3(0.25), rainStrength);

	vec3 fogclr_sunrise = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunrise;
	vec3 fogclr_noon = vec3(0.6, 0.8, 1.27) * 0.5 * TimeNoon;
	vec3 fogclr_sunset = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunset;
	vec3 fogclr_midnight = vec3(0.2, 0.6, 1.3) * 0.01 * TimeMidnight;
	fogcolor = fogclr_sunrise + fogclr_noon + fogclr_sunset + fogclr_midnight;
	fogcolor = mix(fogcolor, fogcolor * totalSkyLight * 0.5, rainStrength);
}
