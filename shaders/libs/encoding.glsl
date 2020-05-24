#ifndef _INCLUDE_ENCODING
#define _INCLUDE_ENCODING

#define CLIPPING_PLANES
#include "uniforms.glsl"

vec3 normalDecode(uint e) {
    vec2 encodedNormal = unpackUnorm2x16(e);
	encodedNormal = encodedNormal * 4.0 - 2.0;
	float f = dot(encodedNormal, encodedNormal);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}

uint normalEncode(vec3 n) {
	vec2 enc = vec2(n.xy * inversesqrt(n.z * 8.0 + 8.0 + 0.00001) + 0.5);
	return packUnorm2x16(enc);
}

#endif