#ifndef _INCLUDE_ENCODING
#define _INCLUDE_ENCODING

#define CLIPPING_PLANES
#include "uniforms.glsl"

uint encode_depth_normal(in vec3 n, in float depth) {
    vec2 enc = normalize(n.xy) * (sqrt(-n.z * 0.5 + 0.5));
    
    enc = clamp(enc * 0.5 + 0.5, 0.0, 1.0) * 255.0;
    depth = clamp(depth, 0.0, 1.0) * 65536;

    return (uint(enc.x) << 24) | (uint(enc.y) << 16) | uint(depth);
}

void decode_depth_normal(in uint i, out vec3 n, out float depth) {
    vec2 enc = vec2(float(i >> 24) / 255.0, float((i >> 16) & 0xFF) / 255.0);

    vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	n = normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));

    depth = float(i & 0xFFFF) / 65536.0;
}

#endif