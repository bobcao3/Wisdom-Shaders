#ifndef _INCLUDE_ENCODING
#define _INCLUDE_ENCODING

#define CLIPPING_PLANES
#include "uniforms.glsl"

#include "/libs/color.glsl"

vec3 normalDecode(uint e) {
    f16vec2 encodedNormal = f16vec2(unpackUnorm2x16(e));
	encodedNormal = encodedNormal * float16_t(4.0) - float16_t(2.0);
	float16_t f = dot(encodedNormal, encodedNormal);
	float16_t g = sqrt(float16_t(1.0) - f * float16_t(0.25));
	return vec3(encodedNormal * g, float16_t(1.0) - f * float16_t(0.5));
}

uint normalEncode(vec3 n) {
	f16vec2 enc = f16vec2(f16vec2(n.xy) * inversesqrt(float16_t(n.z) * float16_t(8.0) + float16_t(8.0 + 0.00001)) + float16_t(0.5));
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

	albedo = fromGamma(vec3(dAlbedo) / vec3(31.0, 63.0, 31.0));
	specular = vec2(dSpecular) / vec2(255.0);
}

#endif