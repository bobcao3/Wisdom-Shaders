#version 120

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

#pragma optimize(on)
#include "libs/compat.glsl"

varying vec2 uv;

#include "GlslConfig"

#define WAO

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"

#define GI

#include "libs/Lighting.frag"

Mask mask;
Material frag;
LightSourcePBR sun;
LightSourceHarmonics ambient;
LightSource torch;

#include "libs/atmosphere.glsl"

varying vec3 sunLight;
varying vec3 sunraw;

varying vec3 ambientU;
varying vec3 ambient0;
varying vec3 ambient1;
varying vec3 ambient2;
varying vec3 ambient3;
varying vec3 ambientD;

varying vec3 worldLightPosition;

#define WAO_ADVANCED

void main() {
  vec3 color = vec3(0.0);

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  if (!mask.is_sky) {
    sun.light.color = sunLight;
    sun.L = lightPosition;

    vec3 wN = mat3(gbufferModelViewInverse) * frag.N;

    float thickness = 1.0, shade = 0.0;
    shade = light_fetch_shadow(shadowtex1, wpos2shadowpos(frag.wpos + (mask.is_grass ? 0.3 : 0.0) * wN), thickness);
    sun.light.attenuation = 1.0 - shade;

    ambient.attenuation = light_mclightmap_simulated_GI(frag.skylight);
    #ifdef DIRECTIONAL_LIGHTMAP
    ambient.attenuation *= lightmap_normals(frag.N, frag.skylight, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
    #endif

    float ao = 1.0;
    #ifdef WAO
    ao  = sum4(textureGatherOffset(gaux2, uv, ivec2( 1, 1)));
    #ifdef WAO_ADVANCED
    ao += sum4(textureGatherOffset(gaux2, uv, ivec2(-1, 1)));
    ao += sum4(textureGatherOffset(gaux2, uv, ivec2(-1,-1)));
    ao += sum4(textureGatherOffset(gaux2, uv, ivec2( 1,-1)));
    ao *= 0.0625;
    #else
    ao *= 0.25;
    #endif
    #endif

    ambient.color0 = ambientU * ao;
    ambient.color1 = ambient0 * ao;
    ambient.color2 = ambient1 * ao;
    ambient.color3 = ambient2 * ao;
    ambient.color4 = ambient3 * ao;
    ambient.color5 = ambientD * ao;

    const vec3 torch1900K = pow(vec3(255.0, 147.0, 41.0) / 255.0, vec3(2.2)) * 0.06;
  	const vec3 torch5500K = vec3(1.2311, 1.0, 0.8286) * 0.1;
  	//#define WHITE_LIGHT
  	#ifndef WHITE_LIGHT
    torch.color = torch1900K;
	  #else
	  torch.color = torch5500K;
	  #endif
    torch.attenuation = light_mclightmap_attenuation(frag.torchlight) * ao;

    float wetness2 = wetness * smoothstep(0.92, 1.0, frag.skylight) * float(!mask.is_plant);
		if (wetness2 > 0.0) {
			float wet = noise((frag.wpos + cameraPosition).xz * 0.5 - frameTimeCounter * 0.02);
			wet += noise((frag.wpos + cameraPosition).xz * 0.6 - frameTimeCounter * 0.01) * 0.5;
			wet = clamp(wetness2 * 3.0, 0.0, 1.0) * clamp(wet * 2.0 + wetness2, 0.0, 1.0);
			
			if (wet > 0.0) {
				frag.roughness = mix(frag.roughness, 0.05, wet);
				frag.metalic = mix(frag.metalic, 0.03, wet);
				frag.N = mix(frag.N, frag.Nflat, wet);
			
				frag.N.x += noise((frag.wpos.xz + cameraPosition.xz) * 5.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				frag.N.y -= noise((frag.wpos.xz + cameraPosition.xz) * 6.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				frag.N = normalize(frag.N);
			}
    }
		
    color = light_calc_PBR(sun, frag, mask.is_plant ? thickness : 1.0, mask.is_grass) + light_calc_diffuse_harmonics(ambient, frag, wN) + light_calc_diffuse(torch, frag);

  	//#define GI_DEBUG
  	#ifdef GI
	  const float weight[3] = float[] (0.3829, 0.2417, 0.0606);
  	float d1 = linearizeDepth(texture2D(depthtex0, uv).r);
  	vec3 gi = vec3(0.0);

  	for (int i = -2; i < 3; i++) {
	  	for (int j = -2; j < 3; j++) {
		  	vec2 coord = uv + vec2(i, j) / vec2(viewWidth, viewHeight) * 1.5;

			  f16vec3 c = texture2D(colortex3, coord).rgb * weight[abs(i)] * weight[abs(j)];
			  float16_t d2 = linearizeDepth(texture2D(depthtex0, coord).r);
  			float16_t bilateral = 1.0 - min(abs(d2 - d1) * 2.0, 1.0);

	  		gi += c * bilateral;
	  	}
	  }

    const float gi_strength = 3.0; // [1.0 3.0 5.0]

	  #ifdef GI_DEBUG
	  color = sunLight * gi;
	  #else
	  color += sunLight * gi * frag.albedo * gi_strength;
	  #endif
	  #endif

	
  	//#define WAO_DEBUG
  	#ifdef WAO_DEBUG
	  color = vec3(ao);
	  #endif
	
    color = mix(color, frag.albedo, frag.emmisive);
  } else {
    vec3 nwpos = normalize(frag.wpos);
    color = texture2D(colortex0, uv).rgb;

    float mu_s = dot(nwpos, worldLightPosition);
    float mu = abs(mu_s);
    #ifdef CLOUDS_2D
    float cmie = calc_clouds(nwpos * 512.0, cameraPosition);
    color *= 1.0 - cmie;

    float opmu2 = 1. + mu*mu;
    float phaseM = .1193662 * (1. - g2) * opmu2 / ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));
    vec3 sunlight = sunraw * 1.3;
    color += (0.3 * luma(sunraw) + sunlight * phaseM) * cmie;
    #endif

    color += scatter(vec3(0., 25e2 + cameraPosition.y, 0.), nwpos, worldLightPosition, Ra);
  	color += sunraw * smoothstep(0.9997, 0.99975, mu_s);
  }

/* DRAWBUFFERS:5 */
  gl_FragData[0] = vec4(color, 0.0);
}
