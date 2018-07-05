/*
 * Copyright 2017 Cheng Cao
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// =============================================================================
//  PLEASE FOLLOW THE LICENSE AND PLEASE DO NOT REMOVE THE LICENSE HEADER
// =============================================================================
//  ANY USE OF THE SHADER ONLINE OR OFFLINE IS CONSIDERED AS INCLUDING THE CODE
//  IF YOU DOWNLOAD THE SHADER, IT MEANS YOU AGREE AND OBSERVE THIS LICENSE
// =============================================================================

#version 120
#include "libs/compat.glsl"
#pragma optimize(on)

uniform sampler2D tex;

varying float data;
varying vec2 uv;
varying vec3 vpos;

varying vec3 sunLight;
varying vec3 sunraw;
varying vec3 ambientU;

varying vec3 N;
varying vec2 lmcoord;

varying vec3 wN;
varying vec3 wT;
varying vec3 wB;

varying vec3 wpos;

varying vec3 worldLightPosition;

varying vec3 glcolor;

#include "GlslConfig"

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/Lighting.frag"
#include "libs/atmosphere.glsl"

#define WATER_PARALLAX
#define WATER_CAUSTICS
#include "libs/Water.frag"

LightSourcePBR sun;
Material frag;

uniform ivec2 eyeBrightness;

const bool depthtex1MipmapEnabled = true;

#define REFRACTION
#define ADVANCED_REFRACTION
#define VARIAED_WATER_HEIGHT

/* DRAWBUFFERS:45 */
void main() {
	vec4 color = vec4(0.0);

	vec3 worldN;

  vec4 watermixcolor = vec4(0.0);

	if (maskFlag(data, waterFlag)) {
		// Water Rendering starts here
		vec4 p = gbufferProjection * vec4(vpos, 1.0);  // Reproject vpos to clip pos
		p /= p.w;                                      //
		vec2 uv1 = p.st * 0.5 + 0.5;                   // Clip pos to UV

		float land_depth = texture2DLod(depthtex1, uv1.st, 0).r;// Read deferred state depth
		vec3 land_vpos = fetch_vpos(uv1.st, land_depth).xyz;    // Read deferred state vpos

		float dist_diff = (isEyeInWater == 1) ? length(vpos) : distance(land_vpos, vpos); // Distance difference - raw (Water absorption)

		#ifdef VARIAED_WATER_HEIGHT
		float16_t land_depth_B;
		land_depth_B  = sum4(textureGather      (gaux2, uv              ));
		land_depth_B += sum4(textureGatherOffset(gaux2, uv, ivec2(-3, 0)));
		land_depth_B += sum4(textureGatherOffset(gaux2, uv, ivec2(-3,-3)));
		land_depth_B += sum4(textureGatherOffset(gaux2, uv, ivec2( 0,-3)));
		land_depth_B *= 0.0625;
		vec3 land_vpos_B = fetch_vpos(uv1.st, land_depth_B).xyz;    // Read deferred state vpos
		vec3 diff_pos = (isEyeInWater == 1) ? vpos : land_vpos_B - vpos;
		float lod = fma(smoothstep(0.0, 1.0, length(diff_pos) * 0.06), 0.9, 0.1);
		#else
		const float lod = 1.0;
		#endif

		// Build material
		material_build(
			frag,
			vpos, wpos, N, N,
			vec3(1.0), vec3(0.95,0.002,0.0), lmcoord);

		// Waving water & parallax
		#ifdef WATER_PARALLAX
		WaterParallax(frag.wpos, lod, wN);
		vec4 reconstruct = gbufferModelView * vec4(frag.wpos, 1.0);
		frag.vpos = reconstruct.xyz;
		frag.nvpos = normalize(frag.nvpos);
		#endif

		float16_t wave = getwave2(frag.wpos + cameraPosition, lod);
		worldN = get_water_normal(frag.wpos + cameraPosition, wave, lod, wN, wT, wB);
		frag.N = mat3(gbufferModelView) * worldN;

		// Refraction
		bool total_refra = false;
		#ifdef REFRACTION
		vec3 refracted = refract(frag.vpos, frag.N, (isEyeInWater == 1) ? 1.33 / 1.00029 : 1.00029 / 1.33);
         total_refra = (refracted == vec3(0.0));
         refracted = frag.vpos + refracted;
		vec2 uv_refra = screen_project(refracted);
		color = texture2D(gaux3, uv_refra);                     // Read deferred state composite, refracted

		#ifdef ADVANCED_REFRACTION
		land_depth = texture2DLod(depthtex1, uv1.st, 0).r;
		// Re-read deferred state depth
		land_vpos = fetch_vpos(uv1.st, land_depth).xyz;         // Re-read deferred state vpos
		if (isEyeInWater != 1)
			dist_diff = distance(land_vpos, vpos);              // Recalc distance difference - raw (Water absorption)
		#endif
		#else
		color = texture2D(gaux3, uv1.st);                       // Read deferred state composite
		#endif

		#ifdef WATER_CAUSTICS
		if (isEyeInWater == 0) {
			vec3 land_wpos = (gbufferModelViewInverse * vec4(land_vpos, 1.0)).xyz;
			color *= smoothstep(0.0, 1.0, fma(get_caustic(land_wpos + cameraPosition), 1.1, 0.5));
		}
		#endif

		float dist_diff_N = min(1.0, dist_diff * 0.03125);       // Distance clamped (0.0 ~ 1.0)
		if (isEyeInWater != 1 && land_depth > 0.9999)
		dist_diff_N = 1.0;                                       // Clamp out the sky behind

		float absorption = pow(2.0 / (dist_diff_N + 1.0) - 1.0, 2.0);     // Water absorption factor
		vec3 watercolor = color.rgb * glcolor
		   * pow(vec3(absorption), vec3(3.0, 0.8, 1.0))         // Water absorption color
			 * (abs(dot(lightPosition, N)) * 0.8 + 0.2);        // Scatter-in factor
		float light_att = (isEyeInWater == 1) ? float(eyeBrightnessSmooth.y) / 240.0 : lmcoord.y;

		const vec3 waterfogcolor = vec3(0.2,1.0,1.2) * 0.01;
		vec3 waterfog = (max(luma(sunLight), 0.0) * light_att) * (waterfogcolor * glcolor);

		if (total_refra) watercolor = waterfog * max(1.0, 2.0 - absorption * 2.0);

		// Refraction color composite
		color = (isEyeInWater == 1) ? vec4(watercolor, 1.0) : vec4(mix(waterfog, watercolor, absorption), 1.0);
		watermixcolor = vec4(waterfog, 1.0 - absorption);

		// Parallax cut-out (depth test)
		if (frag.vpos.z < land_vpos.z) discard;
	} else {
		// Glass / Other transperancy render
		worldN = wN;

		// Get material texture
		color = texture2D(tex, uv);
		color = vec4(fromGamma(color.rgb), color.a);

		// Build material
		material_build(
			frag,
			vpos, wpos, N, N,
			color.rgb, vec3(0.9,0.3,0.0), lmcoord);
	}

	// Setup Sun object
	sun.light.color = sunLight;
	sun.L = lightPosition;

	sun.light.attenuation = 1.0 - light_fetch_shadow_fast(shadowtex0, wpos2shadowpos(frag.wpos + worldN * 0.1));

	// PBR lighting (Diffuse + brdf)
	if (!maskFlag(data, waterFlag)) {
		color.rgb = light_calc_PBR(sun, frag, 1.0, false);
	}

	#define WATER_IBL

	#ifdef WATER_IBL
	// IBL reflection
	vec3 reflected = reflect(normalize(frag.wpos - vec3(0.0, 1.62, 0.0)), worldN);
	vec3 reflectedV = reflect(frag.nvpos, frag.N);

	vec4 ray_traced = vec4(0.0);
	if (dot(reflectedV, N) > 0.0) {
		ray_traced = ray_trace_ssr(reflectedV, frag.vpos, frag.metalic, gaux3, N);
	}
	if (ray_traced.a < 0.95) {
		ray_traced.rgb = mix(
			scatter(vec3(0., 25e2, 0.), reflected, worldLightPosition, Ra) * pow(lmcoord.y, 3.0),
			ray_traced.rgb,
			ray_traced.a
		);
	}

	color = light_calc_PBR_IBL(color, reflectedV, frag, ray_traced.rgb);
	#endif

	// PBR lighting (Diffuse + brdf)
	if (maskFlag(data, waterFlag)) {
		color.rgb += light_calc_PBR_brdf(sun, frag);
		color.a = 1.0;
	}

	if (maskFlag(data, iceFlag)) {
		color.a = fma(color.a, 0.5, 0.5);
	}

	if (isEyeInWater == 1) color.rgb = mix(color.rgb, watermixcolor.rgb, watermixcolor.a);

	// Output
	gl_FragData[0] = vec4(normalEncode(frag.N), waterFlag, 1.0);
	gl_FragData[1] = color;
}
