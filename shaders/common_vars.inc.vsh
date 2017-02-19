uniform int worldTime;
uniform float wetness;
float rainStrength = pow(clamp(wetness, 0.0f, 1.0f), 2.0);

float wTimeF = float(worldTime);

invariant varying vec2 texcoord;
invariant varying vec3 suncolor;

invariant varying float TimeSunrise;
invariant varying float TimeNoon;
invariant varying float TimeSunset;
invariant varying float TimeMidnight;
invariant varying float extShadow;

invariant varying vec3 skycolor;
invariant varying vec3 fogcolor;
invariant varying vec3 horizontColor;

#define SUNRISE 23500
#define SUNSET 12000
#define FADE_START 520
#define FADE_END 350

void calcCommon() {
	TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	vec3 suncolor_sunrise = vec3(2.52, 1.4, 0.4) * TimeSunrise;
	vec3 suncolor_noon = vec3(2.72, 2.35, 2.1) * TimeNoon;
	vec3 suncolor_sunset = vec3(2.52, 1.3, 0.8) * TimeSunset;
	vec3 suncolor_midnight = vec3(0.14, 0.5, 0.9) * 0.04 * TimeMidnight;

	suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
	suncolor *= 1.0 - rainStrength * 0.83;

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

	vec3 fogclr_sunrise = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunrise * (1.0 - rainStrength * 1.0);
	vec3 fogclr_noon = vec3(0.6, 0.8, 1.27) * 0.5 * TimeNoon * (1.0 - rainStrength * 1.0);
	vec3 fogclr_sunset = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunset * (1.0 - rainStrength * 1.0);
	vec3 fogclr_midnight = vec3(0.2, 0.6, 1.3) * 0.01 * TimeMidnight * (1.0 - rainStrength * 1.0);
	vec3 fogclr_rain_day = vec3(2.1, 2.3, 2.55) * 0.2 * (TimeSunrise + TimeNoon + TimeSunset) * rainStrength;
	vec3 fogclr_rain_night = vec3(0.35, 0.7, 1.3) * 0.01  * TimeMidnight * rainStrength;
	fogcolor = fogclr_sunrise + fogclr_noon + fogclr_sunset + fogclr_midnight + fogclr_rain_day + fogclr_rain_night;
}
