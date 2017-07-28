#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 texcoord;

#include "GlslConfig"

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Material.glsl.frag"
#include "Lighting.glsl.frag"
#include "Atomosphere.glsl.frag"

vec2 mclight = texture2D(gaux2, texcoord).xy;

Mask mask;
Material land;


void main() {
	// rebuild hybrid flag
	vec3 normaltex = texture2D(gnormal, texcoord).rgb;
	vec3 water_normal_tex = texture2D(gdepth, texcoord).rgb;
	if (water_normal_tex.b == 1.0) water_normal_tex.b = 0.0;
	float flag = (normaltex.b < 0.11 && normaltex.b > 0.01) ? normaltex.b : max(normaltex.b, water_normal_tex.b);
	if (normaltex.b < 0.09 && water_normal_tex.b > 0.9) flag = 0.99;
	if (normaltex.b > 0.19 && normaltex.b < 0.21 && water_normal_tex.b > 0.98) flag = 0.45;
	

	// build up mask
	init_mask(mask, flag);

	vec3 color = vec3(0.0f);
	if (!mask.is_sky) {
		material_sample(land, texcoord);
		color.r = calcAO(land.N, land.cdepth, land.vpos, texcoord);
		#ifdef HQ_AO
		color.gb = normaltex.rg;
		#endif
	}
	
	// rebuild hybrid data
	vec4 specular_data = flag > 0.89f ? texture2D(gaux4, texcoord) : texture2D(gaux1, texcoord);
	specular_data.a = flag;

/* DRAWBUFFERS:234 */
	gl_FragData[0] = vec4(normaltex.xy, water_normal_tex.xy);
	gl_FragData[1] = vec4(color, 1.0f);
	gl_FragData[2] = specular_data;
}
