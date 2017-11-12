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

//#define DIRECTIONAL_LIGHTMAP

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/Lighting.frag"

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

  vec3 worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);

  if (!mask.is_sky) {
    vec3 wN = mat3(gbufferModelViewInverse) * frag.N;
    vec3 reflected = reflect(normalize(frag.wpos - vec3(0.0, 1.61, 0.0)), wN);
    vec3 reflectedV = reflect(frag.nvpos, frag.N);

    vec4 ray_traced = ray_trace_ssr(reflectedV, frag.vpos, frag.metalic, gaux2, frag.N);
    if (ray_traced.a < 0.9) {
      ray_traced.rgb = mix(
        scatter(vec3(0., 25e2, 0.), reflected, worldLightPosition, Ra),
        ray_traced.rgb,
        ray_traced.a
      );
    }

    color += light_calc_PBR_IBL(reflectedV, frag, ray_traced.rgb);
  }

/* DRAWBUFFERS:56 */
  gl_FragData[0] = vec4(color, 0.0);
  gl_FragData[1] = vec4(color, 0.0);
}
