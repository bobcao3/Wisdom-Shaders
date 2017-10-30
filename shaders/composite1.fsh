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

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
//#include "libs/Lighting.frag"

Mask mask;
Material frag;

//#define CrespecularRays
//#include "libs/atmosphere.glsl"

//#define TAA

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;
  vec4 taa = vec4(0.0);

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  #ifdef TAA
  float TAA_weight = 0.3;
  vec4 prev_pos = vec4(frag.wpos + cameraPosition - previousCameraPosition, 1.0);
  prev_pos = gbufferPreviousModelView * prev_pos;
  vec4 prev_vpos = prev_pos;
  prev_pos = gbufferPreviousProjection * prev_pos;
  prev_pos /= prev_pos.w;

  vec2 uv1 = prev_pos.st * 0.5 + 0.5;
  if (uv1.x < 0.001 || uv1.x > 0.999 || uv1.y < 0.001 || uv1.y > 0.999) TAA_weight = 1.0;
  vec4 prev_col = texture2D(colortex3, uv1);

  float depth = texture2D(depthtex0, uv).r;

  vec4 vpos_prev = fetch_vpos(uv1, prev_col.a);
  TAA_weight = max(TAA_weight, smoothstep(0.0, distance(prev_pos.z, frag.vpos.z) * 0.005, distance(linearizeDepth(depth), linearizeDepth(prev_col.a))));
  //TAA_weight = max(TAA_weight, min(abs(luma(color) - luma(prev_col.rgb)) * 2.0, 1.0));

  color = mix(prev_col.rgb, color, TAA_weight);
  taa = vec4(color, depth);
  #endif

/* DRAWBUFFERS:57 */
  gl_FragData[0] = vec4(color, 0.0);
  gl_FragData[1] = taa;
}
