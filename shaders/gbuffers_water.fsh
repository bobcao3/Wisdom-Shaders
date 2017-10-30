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
#pragma optimize(on)

uniform sampler2D tex;

varying float data;
varying vec2 uv;
varying vec3 vpos;

varying vec3 sunLight;
varying vec3 ambientU;

varying vec3 N;
varying vec2 lmcoord;

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

LightSourcePBR sun;
Material frag;

uniform ivec2 eyeBrightness;

/* DRAWBUFFERS:5 */
void main() {
	vec4 color = vec4(0.0);
	vec3 wpos = (gbufferModelViewInverse * vec4(vpos, 1.0)).xyz;

	sun.light.color = sunLight * 6.0;
	sun.L = lightPosition;

	float thickness = 1.0, shade = 0.0;
	shade = light_fetch_shadow(shadowtex0, 0.1, wpos2shadowpos(wpos), thickness);
	sun.light.attenuation = 1.0 - shade;

	if (maskFlag(data, waterFlag)) {
		vec4 p = gbufferProjection * vec4(vpos, 1.0);
		p /= p.w;
		vec2 uv1 = p.st * 0.5 + 0.5;

		color = texture2D(gaux3, uv1.st);

		vec3 land_vpos = fetch_vpos(uv1.st, depthtex0).xyz;

		float dist_diff = distance(land_vpos, vpos);
		float dist_diff_N = min(1.0, dist_diff * 0.0625);

		float absorption = 2.0 / (dist_diff_N + 1.0) - 1.0;
		vec3 watercolor = color.rgb * pow(vec3(absorption), vec3(2.0, 0.8, 1.0));
		float light_att = lmcoord.y;
		vec3 waterfog = max(luma(ambientU), 0.0) * light_att * vec3(0.1,0.7,0.8);
		color = vec4(mix(waterfog, watercolor, pow(absorption, 2.0)), 1.0);

		material_build(
			frag,
			vpos, wpos, N, N,
			vec3(1.0), vec3(0.98,0.1,0.0), lmcoord);

		color.rgb += light_calc_PBR_brdf(sun, frag);
	} else {
		color = texture2D(tex, uv);
		color = vec4(fromGamma(color.rgb), color.a);

		material_build(
			frag,
			vpos, wpos, N, N,
			color.rgb, vec3(0.9,0.6,0.0), lmcoord);

		color.rgb = light_calc_PBR(sun, frag, 1.0);
	}

	vec3 wN = mat3(gbufferModelViewInverse) * N;
	vec3 reflected = reflect(normalize(wpos - vec3(0.0, 1.61, 0.0)), wN);
	vec3 reflectedV = reflect(vpos, N);

	vec4 ray_traced = ray_trace_ssr(reflectedV, vpos, frag.metalic);
	ray_traced.a = 0.0;
	if (ray_traced.a < 0.9) {
		ray_traced.rgb = mix(
			scatter(vec3(0., 25e2, 0.), reflected, worldLightPosition, Ra),
			ray_traced.rgb,
			ray_traced.a
		);
	}

	color.rgb += light_calc_PBR_IBL(reflected, frag, ray_traced.rgb);

	gl_FragData[0] = color;
}
