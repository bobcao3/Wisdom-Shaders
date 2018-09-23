#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 texcoord;

const bool colortex1MipmapEnabled = true;

#define WATER_CAUSTICS

#include "GlslConfig"

//#define SPACE

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Material.glsl.frag"
#include "Lighting.glsl.frag"
#include "Atomosphere.glsl.frag"
#include "Water.glsl.frag"

vec4 mclight = texture2D(gaux2, texcoord);

LightSource torch;
LightSource amb;
LightSourcePBR sun;
Material land;

Mask mask;

#ifdef WISDOM_AMBIENT_OCCLUSION
#ifdef HQ_AO
//=========== BLUR AO =============
float16_t blurAO (vec2 uv, vec3 N) {
	float16_t z  = texture2D(composite, uv).r;
	float16_t x  = z * 0.2941176f;
	f16vec3  y  = texture2D(composite, uv + vec2(0.0, -pixel.y * 1.333333)).rgb;
	         x += mix(z, y.x, max(0.0, dot(normalDecode(y.yz), N))) * 0.352941176f;
	         y  = texture2D(composite, uv + vec2(0.0,  pixel.y * 1.333333)).rgb;
	         x += mix(z, y.x, max(0.0, dot(normalDecode(y.yz), N))) * 0.352941176f;
	return x;
}
//=================================
#endif
#endif

//#define PRIME_RENDER
//#define MODERN

#define CLOUD_SHADOW

void main() {
	// rebuild hybrid flag
	vec4 speculardata = texture2D(gaux1, texcoord);
	float flag = speculardata.a;

	// build up mask
	init_mask(mask, flag);

	vec3 color = vec3(0.0f);

	// build up materials & light sources
	if (!mask.is_sky) {
		#ifdef MODERN
		const vec3 torch_color = vec3(0.016f, 0.012f, 0.011f) * 10.0f;
		#else
		const vec3 torch_color = vec3(0.2435f, 0.0921f, 0.01053f) * 3.0f;
		#endif
		torch.color = torch_color;
		torch.attenuation = light_mclightmap_attenuation(mclight.x);

		material_sample(land, texcoord);
		#ifdef PRIME_RENDER
		land.albedo = vec3(0.5);
		#endif

		sun.light.color = suncolor;
		float thickness = 1.0;
		float shadow = 0.0;

		shadow = light_fetch_shadow(shadowtex1, light_shadow_autobias(land.cdepthN), wpos2shadowpos(land.wpos), thickness);
		if (isEyeInWater) {
			shadow = max(shadow, 1.0 - mclight.y);
		}

		sun.light.attenuation = 1.0 - max(extShadow, shadow);
		#ifdef WATER_CAUSTICS
		if (((!isEyeInWater && mask.is_water) || (isEyeInWater && !mask.is_water)) && shadow < 0.95) {
			sun.light.attenuation *= fma(worldLightPosition.y, 0.98, 0.02) * (1.3 - get_caustic(land.wpos + cameraPosition));
			
			if (isEyeInWater) sun.light.attenuation *= mclight.y;
		}
		#endif
		sun.L = lightPosition;
		
		#ifdef CLOUD_SHADOW
		vec4 clouds = calc_clouds(worldLightPosition * 512.0f, cameraPosition + land.wpos, 0.0);
		sun.light.attenuation *= 1.0 - clouds.a * 1.6;
		#endif

		amb.color = ambient;
		amb.attenuation = light_mclightmap_simulated_GI(mclight.y, sun.L, land.N);

		#ifdef DIRECTIONAL_LIGHTMAP
		if (!mask.is_hand) {
			
		}
		#endif

		#ifdef WISDOM_AMBIENT_OCCLUSION
		#ifdef HQ_AO
		float ao = blurAO(texcoord, land.N);
		#else
		float ao = texture2D(composite, texcoord).r;
		#endif
		amb.attenuation *= ao;
		torch.attenuation *= ao;
		
		if (mask.is_plant) sun.light.attenuation *= ao;
		#endif
		
		// Force ground wetness
		float wetness2 = wetness * smoothstep(0.92, 1.0, mclight.y) * float(!mask.is_plant);
		if (wetness2 > 0.0 && !(mask.is_water || mask.is_hand || mask.is_entity)) {
			float wet = noise((land.wpos + cameraPosition).xz * 0.5 - frameTimeCounter * 0.02);
			wet += noise((land.wpos + cameraPosition).xz * 0.6 - frameTimeCounter * 0.01) * 0.5;
			wet = clamp(wetness2 * 3.0, 0.0, 1.0) * clamp(wet * 2.0 + wetness2, 0.0, 1.0);
			
			if (wet > 0.0) {
				land.roughness = mix(land.roughness, 0.05, wet);
				land.metalic = mix(land.metalic, 0.03, wet);
				vec3 flat_normal = normalDecode(mclight.zw);
				land.N = mix(land.N, flat_normal, wet);
			
				land.N.x += noise((land.wpos.xz + cameraPosition.xz) * 5.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				land.N.y -= noise((land.wpos.xz + cameraPosition.xz) * 6.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				land.N = normalize(land.N);
			}
		}

		// Light composite
		color += light_calc_PBR(sun, land, mask.is_plant ? thickness : 1.0) + light_calc_diffuse(torch, land) + light_calc_diffuse(amb, land);
		
		// Emmisive
		if (!mask.is_trans) color = mix(color, land.albedo * 2.0, land.emmisive);
	} else {
		vec4 viewPosition = fetch_vpos(texcoord, 1.0);
		vec4 worldPosition = normalize(gbufferModelViewInverse * viewPosition) * 512.0;
		worldPosition.y += cameraPosition.y;
		// Sky
		#ifdef SPACE
		color = vec3(0.0);
		#else
		color = calc_sky_with_sun(worldPosition.xyz, normalize(viewPosition.xyz));
		#endif
		//color = vec3(get_thickness(normalize(worldPosition.xyz)));
	}

/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(max(vec3(0.0), color), 1.0f);
}
