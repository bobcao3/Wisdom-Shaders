uniform int worldTime;
uniform float rainStrength;

varying vec2 texcoord;
varying vec3 suncolor;

varying float extShadow;

varying vec3 fogcolor;
varying vec3 horizontColor;
varying vec3 totalSkyLight;
varying vec3 ambient;

float wTimeF;

void calcCommon() {
	wTimeF = float(worldTime);

	float TimeSunrise  = ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(wTimeF, 0.0, 2000.0)/2000.0));
	float TimeNoon     = ((clamp(wTimeF, 0.0, 2000.0)) / 2000.0) - ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0);
	float TimeSunset   = ((clamp(wTimeF, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0);
	float TimeMidnight = ((clamp(wTimeF, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(wTimeF, 23000.0, 24000.0) - 23000.0) / 1000.0);

	const vec3 suncolor_sunrise = vec3(0.7843, 0.6, 0.313) * 0.7;
	const vec3 suncolor_noon = vec3(1.192, 1.2235, 1.2156) * 1.2;
	const vec3 suncolor_sunset = vec3(0.7843, 0.439, 0.2745) * 0.8;
	const vec3 suncolor_midnight = vec3(0.14, 0.5, 0.9) * 0.02;

	suncolor = suncolor_sunrise * TimeSunrise + suncolor_noon * TimeNoon; + suncolor_sunset * TimeSunset + suncolor_midnight * TimeMidnight;
	suncolor *= 1.0 - rainStrength * 0.99;

	extShadow = (clamp((wTimeF-12000.0)/300.0,0.0,1.0)-clamp((wTimeF-13000.0)/300.0,0.0,1.0) + clamp((wTimeF-22800.0)/200.0,0.0,1.0)-clamp((wTimeF-23400.0)/200.0,0.0,1.0));

	vec3 ambient_sunrise = vec3(0.443, 0.772, 0.886) * 0.4 * TimeSunrise;
	vec3 ambient_noon = vec3(0.176, 0.392, 1.0) * TimeNoon;
	vec3 ambient_sunset = vec3(0.372, 0.615, 0.847) * 0.7 * TimeSunset;
	vec3 ambient_midnight = vec3(0.03, 0.078, 0.117) * 0.2 * TimeMidnight;

	ambient = ambient_sunrise + ambient_noon + ambient_sunset + ambient_midnight;
	ambient *= 1.0 - rainStrength * 0.97;

	vec3 horizontColor_sunrise = vec3(2.1, 1.8, 1.0) * 0.21 * TimeSunrise;
	vec3 horizontColor_noon = vec3(2.1, 2.18, 2.16) * 0.27 * TimeNoon;
	vec3 horizontColor_sunset = vec3(2.1, 1.6, 0.8) * 0.28 * TimeSunset;
	vec3 horizontColor_night = vec3(0.3, 0.7, 1.3) * 0.04 * TimeMidnight;

	horizontColor = horizontColor_sunrise + horizontColor_noon + horizontColor_sunset + horizontColor_night;
	horizontColor *= 1.0 - rainStrength * 0.93;

	totalSkyLight = mix(vec3(0.2, 0.45, 1.0), vec3(0.15), rainStrength);

	vec3 fogclr_sunrise = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunrise;
	vec3 fogclr_noon = vec3(0.6, 0.8, 1.27) * 0.5 * TimeNoon;
	vec3 fogclr_sunset = vec3(0.75, 0.9, 1.27) * 0.5 * TimeSunset;
	vec3 fogclr_midnight = vec3(0.2, 0.6, 1.3) * 0.01 * TimeMidnight;
	fogcolor = fogclr_sunrise + fogclr_noon + fogclr_sunset + fogclr_midnight;
	fogcolor = mix(fogcolor, fogcolor * totalSkyLight * 0.5, rainStrength);
}
