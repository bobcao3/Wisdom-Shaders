#version 120
#include "compat.glsl"
#extension GL_ARB_shader_texture_lod : require
#pragma optimize (on)

varying vec2 texcoord;

#include "GlslConfig"

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Material.glsl.frag"
#include "Lighting.glsl.frag"
#include "Atomosphere.glsl.frag"

const bool depthtex1MipmapEnabled = true;
const bool compositeMipmapEnabled = true;

vec4 mclight = texture2D(gaux2, texcoord);

Material glossy;
Material land;
LightSourcePBR sun;

Mask mask;

#include "Water.glsl.frag"

#define WISDOM_AMBIENT_OCCLUSION
#define WATER_REFRACTION
#define IBL
#define IBL_SSR

void main() {
	// rebuild hybrid flag
	vec4 normaltex = texture2D(gnormal, texcoord);
	vec4 speculardata = texture2D(gaux1, texcoord);
	float flag = speculardata.a;

	// build up mask
	init_mask(mask, flag);

	vec3 color = texture2D(composite, texcoord).rgb;

	if (mask.is_valid || isEyeInWater) {
		material_sample(land, texcoord);
		
		// Transperant
		if (mask.is_trans) {
			material_sample_water(glossy, texcoord);

			float water_sky_light = 0.0;
		
			if (mask.is_water) {
				water_sky_light = glossy.albedo.b * 2.0;
				mclight.y = water_sky_light * 8.5;
				glossy.albedo = vec3(1.0);
				glossy.roughness = 0.1;
				glossy.metalic = 0.03;
				
				vec3 water_plain_normal = mat3(gbufferModelViewInverse) * glossy.N;
				
				float lod = pow(max(water_plain_normal.y, 0.0), 20.0);
				
				#ifdef WATER_PARALLAX
				if (lod > 0.99) WaterParallax(glossy.wpos);
				float wave = getwave2(glossy.wpos + cameraPosition);
				#else
				float wave = getwave2(glossy.wpos + cameraPosition);
				vec2 p = glossy.vpos.xy / glossy.vpos.z * wave;
				wave = getwave2(glossy.wpos + cameraPosition - vec3(p.x, 0.0, p.y));
				vec2 wp = length(p) * normalize(glossy.wpos).xz;
				glossy.wpos -= vec3(wp.x, 0.0, wp.y);
				#endif
				
				vec3 water_normal = (lod > 0.99) ? get_water_normal(glossy.wpos + cameraPosition, wave * water_plain_normal) : water_plain_normal;
				
				glossy.N = mat3(gbufferModelView) * water_normal;
				glossy.vpos = (!mask.is_water && isEyeInWater) ? glossy.vpos : (gbufferModelView * vec4(glossy.wpos, 1.0)).xyz;
				
				// Refraction
				#ifdef WATER_REFRACTION
				vec3 refract_vpos = refract(land.vpos - glossy.vpos, glossy.N, 1.0 / 1.3);
				land.vpos = refract_vpos + glossy.vpos;
				land.nvpos = normalize(land.vpos);
								
				vec2 uv = screen_project(land.vpos);
				uv = mix(uv, texcoord, pow(abs(uv - vec2(0.5)) * 2.0, vec2(2.0)));
				color = texture2DLod(composite, uv, 1.0).rgb * 0.5;
				color += texture2DLod(composite, uv, 2.0).rgb * 0.3;
				color += texture2DLod(composite, uv, 3.0).rgb * 0.2;
				#endif
				
				glossy.nvpos = normalize(glossy.vpos);
			} else {
				glossy.albedo = mix(glossy.albedo, vec3(1.0), 0.2);
				
				glossy.roughness = 0.05;
				glossy.metalic = 0.95;
				
				color = texture2DLod(composite, texcoord, 1.0).rgb * 0.5;
				color += texture2DLod(composite, texcoord, 2.0).rgb * 0.3;
				color += texture2DLod(composite, texcoord, 3.0).rgb * 0.2;
			}
		
			// Render
			if (mask.is_water || isEyeInWater) {
				float dist_diff = isEyeInWater ? min(length(land.vpos), length(glossy.vpos)) : distance(land.vpos, glossy.vpos);
				float dist_diff_N = min(1.0, dist_diff * 0.125);
			
				// Absorbtion
				float absorbtion = 2.0 / (dist_diff_N + 1.0) - 1.0;
				vec3 watercolor = color * pow(vec3(absorbtion), vec3(1.0, 0.4, 0.5));
				vec3 waterfog = luma(ambient) * water_sky_light * vec3(0.1,0.19,0.22) * 8.0;
				color = mix(waterfog, watercolor, smoothstep(0.0, 1.0, absorbtion));
			} else {
				color *= glossy.albedo;
			}
			
			sun.light.color = suncolor;
			float shadow = light_fetch_shadow_fast(shadowtex1, light_shadow_autobias(land.cdepthN), wpos2shadowpos(glossy.wpos));
			shadow = max(extShadow, shadow);
			sun.light.attenuation = 1.0 - extShadow - shadow;
			sun.L = lightPosition;
			
			color += light_calc_PBR_brdf(sun, glossy);
			
			land = glossy;
		} else {
			// Force ground wetness
			float wetness2 = wetness * pow(mclight.y, 5.0) * float(!mask.is_plant);
			if (wetness2 > 0.1) {
				float wet = noise((land.wpos + cameraPosition).xz * 0.15);
				wet += noise((land.wpos + cameraPosition).xz * 0.3) * 0.5;
				wet = sqrt(clamp(smoothstep(0.15, 0.3, wetness2) * wet * 2.0, 0.0, 1.0));
				
				land.roughness = mix(land.roughness, 0.05, wet);
				land.metalic = mix(land.roughness, 0.95, wet);
				vec3 flat_normal = normalDecode(mclight.zw);
				land.N = mix(land.N, flat_normal, wet);
			}
		}
		
		#ifdef IBL
		// IBL
		if (land.roughness < 0.99) {
			vec3 viewRef = reflect(land.nvpos, land.N);
			#ifdef IBL_SSR
			vec4 glossy_reflect = ray_trace_ssr(viewRef, land.vpos, land.roughness);
			vec3 skyReflect = vec3(0.0);
			if (glossy_reflect.a < 0.95) skyReflect = calc_sky((mat3(gbufferModelViewInverse) * viewRef) * 512.0, viewRef);
			vec3 ibl = mix(skyReflect * mclight.y, glossy_reflect.rgb, glossy_reflect.a);
			#else
			vec3 skyReflect = calc_sky((mat3(gbufferModelViewInverse) * viewRef) * 512.0, viewRef);
			#endif
			color += light_calc_PBR_IBL(viewRef, land, ibl);
		}
		#endif
		
		// Atmosphere
		vec3 atmosphere = calc_atmosphere(land.wpos, land.nvpos);
	
		float lit_strength = 1.0;
		#ifdef CrespecularRays
		lit_strength = VL(land.wpos, land.cdepth);
		#endif

		calc_fog_height (land, 0.0, 512.0 * (1.0 - 0.5 * rainStrength), color, atmosphere * (0.3 + lit_strength * 0.7));
	}

/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(color, 1.0f);
}
