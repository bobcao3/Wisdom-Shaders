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

#include "libs/compat.glsl"
#pragma optimize(on)

varying vec2 uv;

#include "GlslConfig"

#define SSR

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/Lighting.frag"

//#define GI

const bool gaux4MipmapEnabled = true;

Mask mask;
Material frag;
//LightSourcePBR sun;
//LightSourceHarmonics ambient;

#include "libs/atmosphere.glsl"

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);
  vec3 gi = vec3(0.0);

  vec3 worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);

  if (!mask.is_sky) {
    float wetness2 = wetness * smoothstep(0.92, 1.0, frag.skylight) * float(!mask.is_plant);
		if (wetness2 > 0.0) {
			float wet = noise((frag.wpos + cameraPosition).xz * 0.5 - frameTimeCounter * 0.02);
			wet += noise((frag.wpos + cameraPosition).xz * 0.6 - frameTimeCounter * 0.01) * 0.5;
			wet = clamp(wetness2 * 3.0, 0.0, 1.0) * clamp(wet * 2.0 + wetness2, 0.0, 1.0);
			
			if (wet > 0.0) {
				frag.roughness = mix(frag.roughness, 0.02, wet);
				frag.metalic = mix(frag.metalic, 0.03, wet);
				frag.N = mix(frag.N, frag.Nflat, wet);
			
				frag.N.x += noise((frag.wpos.xz + cameraPosition.xz) * 5.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				frag.N.y -= noise((frag.wpos.xz + cameraPosition.xz) * 6.0 - vec2(frameTimeCounter * 2.0, 0.0)) * 0.05 * wet;
				frag.N = normalize(frag.N);
			}
    }

    //#define GI_DEBUG
  	#ifdef GI
    float weight = 0.0;

    vec3 c_center = texture2D(colortex3, uv).rgb;
    //gi += c_center;

  	for (int i = -3; i < 4; i++) {
		  vec2 coord = uv + vec2(0.0, i / viewHeight);

			vec3 c = texture2D(gaux3, coord).rgb;
  		float bilateral = max(dot(normalDecode(texture2D(gaux1, coord).rg), frag.N), 0.0);
      #ifdef MC_GL_VENDOR_INTEL
      if (bilateral < 0.1) break;
      #endif

      if (bilateral > 0.1) {
  	  	weight += 1.0;
        gi += mix(c_center, c, bilateral);
      }
	  }

    gi /= weight;

    const float gi_strength = 0.5; // [0.25 0.5 1.0]

    #ifdef GI_DEBUG
	  color = gi * gi_strength;
	  #else
	  color += gi * frag.albedo * gi_strength;
	  #endif
	  #endif

    vec3 wN = mat3(gbufferModelViewInverse) * frag.N;
    vec3 reflected = reflect(normalize(frag.wpos - vec3(0.0, 1.61, 0.0)), wN);
    float n = noise((frag.wpos.xy + vec2(frag.wpos.z, frameTimeCounter)) * 512.0) * frag.roughness;
    vec3 reflectedV = reflect(frag.nvpos, frag.N);
  	reflectedV = normalize(reflectedV + vec3(n, -n, fract(2 * n)) * 0.01);

    vec4 ray_traced = vec4(0.0);
    #ifdef SSR
    ray_traced = ray_trace_ssr(reflectedV, frag.vpos, frag.metalic, gaux2, frag.N);
    if (ray_traced.a < 0.9) {
      ray_traced.rgb = mix(
        texture2DLod(gaux4, project_skybox2uv(reflected), floor(min(3.0, 3.0 * frag.roughness))).rgb * frag.skylight,
        ray_traced.rgb,
        ray_traced.a
      );
    }
    #else
    ray_traced.rgb = scatter(vec3(0., 25e2, 0.), reflected, worldLightPosition, Ra) * frag.skylight;
    #endif
    
    color = light_calc_PBR_IBL(color, reflectedV, frag, ray_traced.rgb);
  }

/* DRAWBUFFERS:56 */
  gl_FragData[0] = vec4(color, 0.0);
  gl_FragData[1] = vec4(color, 0.0);
}
