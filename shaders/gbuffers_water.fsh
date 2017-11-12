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
varying vec3 ambientU;

varying vec3 N;
varying vec2 lmcoord;

varying vec3 wN;
varying vec3 wT;
varying vec3 wB;

varying vec3 wpos;

varying vec3 worldLightPosition;

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
#include "libs/Water.frag"

LightSourcePBR sun;
Material frag;

uniform ivec2 eyeBrightness;

#define REFRACTION
#define ADVANCED_REFRACTION

/* DRAWBUFFERS:45 */
void main() {
	vec4 color = vec4(0.0);

	vec3 worldN;

	if (maskFlag(data, waterFlag)) {
		// Water Rendering starts here
		vec4 p = gbufferProjection * vec4(vpos, 1.0);  // Reproject vpos to clip pos
		p /= p.w;                                      //
		vec2 uv1 = p.st * 0.5 + 0.5;                   // Clip pos to UV

		float land_depth = texture2DLod(depthtex0, uv1.st, 0).r;// Read deferred state depth
		vec3 land_vpos = fetch_vpos(uv1.st, land_depth).xyz;    // Read deferred state vpos

		float dist_diff = distance(land_vpos, vpos);            // Distance difference - raw (Water absorption)

		float lod = 1.0;//abs(wN.y) * 0.5 + 0.5;

		// Build material
		material_build(
			frag,
			vpos, wpos, N, N,
			vec3(1.0), vec3(0.95,0.002,0.0), lmcoord);

		// Waving water & parallax
		WaterParallax(frag.wpos, lod, wN);
		vec4 reconstruct = gbufferModelView * vec4(frag.wpos, 1.0);
		frag.vpos = reconstruct.xyz;
		frag.nvpos = normalize(frag.nvpos);

		float16_t wave = getwave2(frag.wpos + cameraPosition, lod);
		worldN = get_water_normal(frag.wpos + cameraPosition, wave, lod, wN, wT, wB);
		frag.N = mat3(gbufferModelView) * worldN;

		// Refraction
		#ifdef REFRACTION
		vec3 refracted = frag.vpos + refract(frag.nvpos, frag.N, 1.0 / 1.22) * dist_diff;
		vec2 uv_refra = screen_project(refracted);
		color = texture2D(gaux3, uv_refra);                     // Read deferred state composite, refracted

		#ifdef ADVANCED_REFRACTION
		land_depth = texture2DLod(depthtex0, uv1.st, 0).r;      // Re-read deferred state depth
		land_vpos = fetch_vpos(uv1.st, land_depth).xyz;         // Re-read deferred state vpos
		dist_diff = distance(land_vpos, vpos);                  // Recalc distance difference - raw (Water absorption)
		#endif
		#else
		color = texture2D(gaux3, uv1.st);                       // Read deferred state composite
		#endif

		float dist_diff_N = min(1.0, dist_diff * 0.0625);       // Distance clamped (0.0 ~ 1.0)
		if (land_depth > 0.9999) dist_diff_N = 1.0;             // Clamp out the sky behind

		float absorption = 2.0 / (dist_diff_N + 1.0) - 1.0;     // Water absorption factor
		vec3 watercolor = color.rgb
		   * pow(vec3(absorption), vec3(2.0, 0.8, 1.0))         // Water absorption color
			 * (max(dot(lightPosition, N), 0.0) * 0.8 + 0.2);     // Scatter-in factor
		float light_att = lmcoord.y;                            // Sky scatter factor
		vec3 waterfog = max(luma(ambientU), 0.0) * light_att * vec3(0.1,0.7,0.8);

		// Refraction color composite
		color = vec4(mix(waterfog, watercolor, pow(absorption, 2.0)), 1.0);

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
			color.rgb, vec3(0.9,0.6,0.0), lmcoord);
	}

	// Setup Sun object
	sun.light.color = sunLight * 6.0;
	sun.L = lightPosition;

	sun.light.attenuation = 1.0 - light_fetch_shadow_fast(shadowtex0, 0.02, wpos2shadowpos(frag.wpos));

	// PBR lighting (Diffuse + brdf)
	if (maskFlag(data, waterFlag)) {
		color.rgb += light_calc_PBR_brdf(sun, frag);
	} else {
		color.rgb = light_calc_PBR(sun, frag, 1.0);
	}

	// IBL reflection
	vec3 reflected = reflect(normalize(frag.wpos - vec3(0.0, 1.62, 0.0)), worldN);
	vec3 reflectedV = reflect(frag.nvpos, frag.N);

	vec4 ray_traced = vec4(0.0);
	if (dot(reflectedV, N) > 0.0) {
		ray_traced = ray_trace_ssr(reflectedV, frag.vpos, frag.metalic, gaux3, N);
	}
	if (ray_traced.a < 0.95) {
		ray_traced.rgb = mix(
			scatter(vec3(0., 25e2, 0.), reflected, worldLightPosition, Ra),
			ray_traced.rgb,
			ray_traced.a
		);
	}

	color.rgb += light_calc_PBR_IBL(reflectedV, frag, ray_traced.rgb);

	// Output
	gl_FragData[0] = vec4(normalEncode(frag.N), waterFlag, 1.0);
	gl_FragData[1] = color;
}
