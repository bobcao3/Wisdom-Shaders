#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 texcoord;

//#define SPACE

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

#define WATER_PARALLAX

#include "Water.glsl.frag"

#define WISDOM_AMBIENT_OCCLUSION
#define WATER_REFRACTION
#define IBL
#define IBL_SSR

//#define GLASS_REFRACTION

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
		
		float total_internal_reflection = 0.0;
		
		// Transperant
		if (mask.is_trans || isEyeInWater || mask.is_particle) {
			material_sample_water(glossy, texcoord);

			float water_sky_light = 0.0;
		
			if (mask.is_water) {
				water_sky_light = pow(glossy.albedo.b, 1.0f / 2.2f) * 9.8097;
				if (!isEyeInWater) mclight.y = water_sky_light;
				glossy.albedo = vec3(1.0);
				glossy.roughness = 0.05;
				glossy.metalic = 0.01;
				
				vec3 water_plain_normal = mat3(gbufferModelViewInverse) * glossy.N;
				if (isEyeInWater) water_plain_normal = -water_plain_normal;
				
				float lod = pow(max(water_plain_normal.y, 0.0), 4.0);
				
				#ifdef WATER_PARALLAX
				if (lod > 0.0) WaterParallax(glossy.wpos, lod);
				float wave = getwave2(glossy.wpos + cameraPosition, lod);
				#else
				float wave = getwave2(glossy.wpos + cameraPosition, lod);
				vec2 p = glossy.vpos.xy / glossy.vpos.z * wave;
				vec2 wp = length(p) * normalize(glossy.wpos).xz * 0.1;
				glossy.wpos -= vec3(wp.x, 0.0, wp.y);
				#endif
				
				vec3 water_normal = (lod > 0.99) ? get_water_normal(glossy.wpos + cameraPosition, wave, lod, water_plain_normal) : water_plain_normal;
				if (isEyeInWater) water_normal = -water_normal;
				
				glossy.N = mat3(gbufferModelView) * water_normal;
				glossy.vpos = (!mask.is_water && isEyeInWater) ? glossy.vpos : (gbufferModelView * vec4(glossy.wpos, 1.0)).xyz;
				glossy.nvpos = normalize(glossy.vpos);
				
				// Refraction
				#ifdef WATER_REFRACTION
				float l = min(32.0, length(land.vpos - glossy.vpos));
				vec3 refract_vpos = refract(glossy.nvpos, glossy.N, isEyeInWater ? 1.33 / 1.00029 : 1.00029 / 1.33);
				if (refract_vpos != vec3(0.0)) {
					if (!isEyeInWater) l *= (0.2 + max(0.0, dot(glossy.nvpos, glossy.N)) * 0.8);
					vec2 uv = screen_project(refract_vpos * l + glossy.vpos);
					uv = mix(uv, texcoord, pow(abs(uv - vec2(0.5)) * 2.0, vec2(2.0)));
				
					land.vpos = fetch_vpos(uv, depthtex1).xyz;
					land.cdepth = length(land.vpos);
					land.nvpos = land.vpos / land.cdepth;
					land.cdepthN = land.cdepth / far;
				
					color = texture2DLod(composite, uv, 1.0).rgb * 0.5;
					color += texture2DLod(composite, uv, 2.0).rgb * 0.3;
					color += texture2DLod(composite, uv, 3.0).rgb * 0.2;
				} else {
					color = vec3(0.0);
					total_internal_reflection = max(0.0, -dot(glossy.nvpos, glossy.N));
				}
				#endif
				
				glossy.cdepth = length(glossy.vpos);
				glossy.cdepthN = glossy.cdepth / far;
			} else if (!isEyeInWater && flag < 0.98 && !mask.is_particle) {
				glossy.roughness = 0.3;
				glossy.metalic = 0.8;
				
				vec2 uv = texcoord;
				#ifdef GLASS_REFRACTION
				if (land.cdepthN < 1.0) {
					vec3 refract_vpos = refract(glossy.nvpos, glossy.N, 1.00029 / 1.52);
					uv = screen_project(refract_vpos + land.vpos - land.nvpos);
					//uv = mix(uv, texcoord, pow(abs(uv - vec2(0.5)) * 2.0, vec2(2.0)));
				
					land.vpos = fetch_vpos(uv, depthtex1).xyz;
					land.cdepth = length(land.vpos);
					land.nvpos = land.vpos / land.cdepth;
					land.cdepthN = land.cdepth / far;
				}
				#endif
				
				color = texture2DLod(composite, uv, 0.0).rgb * 0.2;
				color += texture2DLod(composite, uv, 1.0).rgb * 0.3;
				color += texture2DLod(composite, uv, 2.0).rgb * 0.5;
				
				float n = noise((glossy.wpos.xz + cameraPosition.xz) * 0.06) * 0.05;
				glossy.N.x += n;
				glossy.N.y -= n;
				glossy.N.z += n;
				glossy.N = normalize(glossy.N);
				
				color = color * glossy.albedo * 2.0;
			} else {
				color = mix(color, glossy.albedo, glossy.opaque * (float(mask.is_sky) * 0.7 + 0.3));
			}
		
			float shadow = 1.0;
			if (!isEyeInWater && flag < 0.98) shadow = light_fetch_shadow_fast(shadowtex1, light_shadow_autobias(land.cdepthN), wpos2shadowpos(glossy.wpos));
		
			// Render
			if (mask.is_water || isEyeInWater) {
				float dist_diff = isEyeInWater ? length(glossy.vpos) : distance(land.vpos, glossy.vpos);
				dist_diff += total_internal_reflection * 4.0;
				float dist_diff_N = min(1.0, dist_diff * 0.0625);
			
				// Absorption
				float absorption = 2.0 / (dist_diff_N + 1.0) - 1.0;
				vec3 watercolor = color * pow(vec3(absorption), vec3(2.0, 0.8, 1.0));
				float light_att = (isEyeInWater) ? (eyeBrightness.y * 0.0215 * (total_internal_reflection + 1.0) + 0.01) : max(water_sky_light, 1.0 - shadow);
				vec3 waterfog = max(luma(ambient) * 0.28, 0.0) * light_att * vec3(0.1,0.7,0.8);
				color = mix(waterfog, watercolor, pow(absorption, 2.0));
			}
			
			#ifndef SPACE
			if (!isEyeInWater && (flag < 0.98 || mask.is_sky)) {
				sun.light.color = suncolor;
				shadow = max(extShadow, shadow);
				sun.light.attenuation = 1.0 - shadow;
				sun.L = lightPosition;
			
				color += light_calc_PBR_brdf(sun, glossy);
				
				land = glossy;
			}
			#endif
			
			if (isEyeInWater && total_internal_reflection > 0.0) land = glossy;
		} else {
			// Force ground wetness
			float wetness2 = wetness * smoothstep(0.92, 1.0, mclight.y) * float(!mask.is_plant);
			if (wetness2 > 0.0 && !(mask.is_water || mask.is_hand || mask.is_entity)) {
				float wet = noise((land.wpos + cameraPosition).xz * 0.5 - frameTimeCounter * 0.02);
				wet += noise((land.wpos + cameraPosition).xz * 0.6 - frameTimeCounter * 0.01) * 0.5;
				wet = clamp(wetness2 * 3.0, 0.0, 1.0) * clamp(wet * 2.0 + wetness2, 0.0, 1.0);
				
				if (wet > 0.0) {
					land.roughness = mix(land.roughness, 0.05, wet);
					land.metalic = mix(land.metalic, 0.03, wet);
					if (mclight.w > 0.5) {
						vec3 flat_normal = normalDecode(mclight.zw);
						land.N = mix(land.N, flat_normal, wet);
					}
				
					color *= 1.0 - wet * 0.6;
				
					land.N.x += noise((land.wpos.xz + cameraPosition.xz) * 5.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
					land.N.y -= noise((land.wpos.xz + cameraPosition.xz) * 6.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
					land.N = normalize(land.N);

					color = mix(color, color * 0.3, wet * (1.0 - abs(dot(land.nvpos, land.N))));
				}
			}
		}
		
		#ifdef IBL
		// IBL
		if (land.roughness < 0.6) {
			vec3 viewRef = reflect(land.nvpos, land.N);
			#ifdef IBL_SSR
			vec4 glossy_reflect = ray_trace_ssr(viewRef, land.vpos, land.roughness);
			vec3 skyReflect = vec3(0.0);
			if (!isEyeInWater && glossy_reflect.a < 0.95) skyReflect = calc_sky((mat3(gbufferModelViewInverse) * viewRef) * 512.0 + vec3(0.0, cameraPosition.y + land.wpos.y, 0.0), viewRef, cameraPosition + land.wpos.xyz);
			vec3 ibl = mix(skyReflect * smoothstep(0.0, 0.5, mclight.y), glossy_reflect.rgb, glossy_reflect.a);
			#else
			vec3 ibl = isEyeInWater ? vec3(0.0) : calc_sky((mat3(gbufferModelViewInverse) * viewRef) * 512.0, viewRef, cameraPosition + land.wpos.xyz);
			#endif
			vec3 calc_IBL = light_calc_PBR_IBL(viewRef, land, ibl);
			if (isEyeInWater) calc_IBL *= total_internal_reflection;
			color += calc_IBL;
		}
		#endif
		
		// Atmosphere
		#ifndef SPACE
		vec3 atmosphere = calc_atmosphere(land.wpos, land.nvpos);
	
		float lit_strength = 1.0;
		#ifdef CrespecularRays
		float vl = 0.0;
		if (!isEyeInWater) {
			lit_strength = VL(land.wpos, vl);
			color += 0.008 * pow(vl, 0.35) * suncolor;
		}
		#endif

		if (!isEyeInWater) calc_fog_height (land, 0.0, 512.0 * (1.0 - cloud_coverage), color, atmosphere * (0.7 * lit_strength + 0.3));
		#endif
	}
	
	#ifdef XLLLLL
	color=vec3(1.0,0.0,0.0);
	#endif

/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(color, 1.0f);
}
