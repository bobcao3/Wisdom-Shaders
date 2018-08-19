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

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/Lighting.frag"

Mask mask;
Material frag;

//#define CLOUD_CRESPECULAR

#define CrespecularRays
#include "libs/atmosphere.glsl"

varying vec3 sunLight;
varying vec3 ambientU;

void main() {
  vec3 color = vec3(1.0);

  float flag;
  material_sample_partial(frag, uv, (isEyeInWater == 1) ? texture2D(depthtex1, uv).r : texture2D(depthtex0, uv).r, flag);

  init_mask(mask, flag, uv);

  // Calculate atmospheric scattering depth
  #ifdef CLOUD_CRESPECULAR
  if (mask.is_sky) frag.wpos *= 768.0 / far;
  #else
  if (!mask.is_sky) {
  #endif
    #ifdef CrespecularRays
    vec3 worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);

    float vl_raw;
    float lit_distance = VL(uv, frag.wpos, vl_raw, worldLightPosition);

    color.r = lit_distance;
    #else
    color.r = 1.0;
    #endif
  #ifdef CLOUD_CRESPECULAR

  #else
  }
  #endif

/* DRAWBUFFERS:0 */
  gl_FragData[0] = vec4(color, 1.0);
}
