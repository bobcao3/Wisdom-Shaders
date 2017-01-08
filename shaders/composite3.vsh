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

	worldLightPos = normalize((gbufferModelViewInverse * vec4(shadowLightPosition, 1.0)).xyz);
}
