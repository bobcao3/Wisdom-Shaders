#ifndef _INCLUDE_ENCODING
#define _INCLUDE_ENCODING

#define CLIPPING_PLANES
#include "uniforms.glsl"

vec3 normalDecode(uint e) {
    vec2 enc = unpackUnorm2x16(e);
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));
}

uint normalEncode(vec3 n) {
	vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
	enc = enc*0.5+0.5;
	return packUnorm2x16(enc);
}

#endif