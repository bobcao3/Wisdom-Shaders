#ifndef _INCLUDE_MATERIAL
#define _INCLUDE_MATERIAL

#include "CompositeUniform.glsl.frag"

//==============================================================================
// Normals
//==============================================================================

vec3 normalDecode(vec2 encodedNormal) {
	encodedNormal = encodedNormal * 4.0 - 2.0;
	float f = dot(encodedNormal, encodedNormal);
	float g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}

//==============================================================================
// Material
//==============================================================================

struct Material {
	vec3 vpos;
	vec3 nvpos;
	vec3 wpos;
	float cdepth;
	float cdepthN;
	vec3 N;

	vec3 albedo;

	float metalic;
	float roughness;
	float emmisive;
	float opaque; 
};

void material_build(
	out Material mat,
	in vec3 vpos, in vec3 wpos, in vec3 N,
	in vec3 albedo, in vec3 specular
) {
	mat.vpos = vpos;
	mat.nvpos = normalize(vpos);
	mat.wpos = wpos;
	mat.N = N;

	mat.albedo = albedo;

	mat.cdepth = length(vpos);
	mat.cdepthN = length(vpos) / far;

	mat.roughness = clamp(1.0 - specular.r, 0.002f, 0.99f);
	mat.metalic = clamp(specular.g, 0.002f, 0.999f);
	mat.emmisive = clamp(specular.b, 0.0f, 1.0f);
}

void material_sample(out Material mat, in vec2 uv) {
	vec4 vpos = fetch_vpos(uv, depthtex1);
	vec3 normal = normalDecode(texture2D(gnormal, uv).rg);
	vec4 spec = texture2D(gaux1, uv);
	material_build(
		mat,
		vpos.xyz, (gbufferModelViewInverse * vpos).xyz, normal,
		pow(texture2D(gcolor, uv).rgb, vec3(2.2f)), spec.rgb
	);
	mat.opaque = spec.b;
}

void material_sample_water(out Material mat, in vec2 uv) {
	vec4 vpos = fetch_vpos(uv, depthtex0);
	vec3 normal = normalDecode(texture2D(gnormal, uv).ba);
	vec4 spec = texture2D(gaux1, uv);
	material_build(
		mat,
		vpos.xyz, (gbufferModelViewInverse * vpos).xyz, normal,
		pow(texture2D(gaux4, uv).rgb, vec3(2.2f)), spec.rgb
	);
	mat.opaque = spec.b;
}

//==============================================================================
// Mask
//==============================================================================

struct Mask {
	float flag;

	bool is_valid;
	bool is_water;
	bool is_trans;
	bool is_glass;
	bool is_plant;
	bool is_sky;
	bool is_hand;
	bool is_entity;
};

void init_mask(inout Mask m, in float flag) {
	m.flag = flag;
	float ndep = texture2D(depthtex1, texcoord).r;
	m.is_sky = ndep >= 1.0;
	m.is_water = (flag > 0.71f && flag < 0.79f);
	m.is_glass = (flag > 0.93);
	m.is_trans = m.is_water || m.is_glass;
	m.is_valid = (flag > 0.01 && flag < 0.97) && (!m.is_sky) || m.is_trans;
	m.is_plant = (flag > 0.48 && flag < 0.53);
	m.is_hand = m.is_valid && flag < 0.11;
	m.is_entity = (flag > 0.35 && flag < 0.4);
}

#endif
