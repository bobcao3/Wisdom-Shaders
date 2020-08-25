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

uint encodeAlbedoSpecular(vec3 albedo, vec2 specular)
{
	ivec3 dAlbedo = ivec3(round(albedo * vec3(31.0, 63.0, 31.0)));
	ivec2 dSpecular = ivec2(floor(specular * vec2(255.0)));
	uint enc = (dAlbedo.r << 11) | (dAlbedo.g << 5) | (dAlbedo.b);
	enc = enc | (dSpecular.r << 24) | (dSpecular.g << 16);
	
	return enc;
}

void decodeAlbedoSpecular(uint enc, out vec3 albedo, out vec2 specular)
{
	ivec3 dAlbedo = ivec3((enc >> 11) & 0x1F, (enc >> 5) & 0x3F, enc & 0x1F);
	ivec2 dSpecular = ivec2(enc >> 24, (enc >> 16) & 0xFF);

	albedo = vec3(dAlbedo) / vec3(31.0, 63.0, 31.0);
	specular = vec2(dSpecular) / vec2(255.0);
}

#endif