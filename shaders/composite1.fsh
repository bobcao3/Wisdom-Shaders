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

#ifdef TAA
void TemporalAntiJitterProjPos(inout vec4 pos, int backward) {
	const vec2 haltonSequenceOffsets[16] = vec2[16](vec2(-1, -1), vec2(0, -0.3333333), vec2(-0.5, 0.3333334), vec2(0.5, -0.7777778), vec2(-0.75, -0.1111111), vec2(0.25, 0.5555556), vec2(-0.25, -0.5555556), vec2(0.75, 0.1111112), vec2(-0.875, 0.7777778), vec2(0.125, -0.9259259), vec2(-0.375, -0.2592592), vec2(0.625, 0.4074074), vec2(-0.625, -0.7037037), vec2(0.375, -0.03703701), vec2(-0.125, 0.6296296), vec2(0.875, -0.4814815));
	const vec2 bayerSequenceOffsets[16] = vec2[16](vec2(0, 3) / 16.0, vec2(8, 11) / 16.0, vec2(2, 1) / 16.0, vec2(10, 9) / 16.0, vec2(12, 15) / 16.0, vec2(4, 7) / 16.0, vec2(14, 13) / 16.0, vec2(6, 5) / 16.0, vec2(3, 0) / 16.0, vec2(11, 8) / 16.0, vec2(1, 2) / 16.0, vec2(9, 10) / 16.0, vec2(15, 12) / 16.0, vec2(7, 4) / 16.0, vec2(13, 14) / 16.0, vec2(5, 6) / 16.0);
	const vec2 otherOffsets[16] = vec2[16](vec2(0.375, 0.4375), vec2(0.625, 0.0625), vec2(0.875, 0.1875), vec2(0.125, 0.0625),
vec2(0.375, 0.6875), vec2(0.875, 0.4375), vec2(0.625, 0.5625), vec2(0.375, 0.9375),
vec2(0.625, 0.3125), vec2(0.125, 0.5625), vec2(0.125, 0.8125), vec2(0.375, 0.1875),
vec2(0.875, 0.9375), vec2(0.875, 0.6875), vec2(0.125, 0.3125), vec2(0.625, 0.8125)
);
	pos.xy -= ((bayerSequenceOffsets[int(mod(frameCounter - backward, 12))] * 2.0 - 1.0) / vec2(viewWidth, viewHeight));
}

void TemporalJitterProjPos(inout vec4 pos, int backward) {
	const vec2 haltonSequenceOffsets[16] = vec2[16](vec2(-1, -1), vec2(0, -0.3333333), vec2(-0.5, 0.3333334), vec2(0.5, -0.7777778), vec2(-0.75, -0.1111111), vec2(0.25, 0.5555556), vec2(-0.25, -0.5555556), vec2(0.75, 0.1111112), vec2(-0.875, 0.7777778), vec2(0.125, -0.9259259), vec2(-0.375, -0.2592592), vec2(0.625, 0.4074074), vec2(-0.625, -0.7037037), vec2(0.375, -0.03703701), vec2(-0.125, 0.6296296), vec2(0.875, -0.4814815));
	const vec2 bayerSequenceOffsets[16] = vec2[16](vec2(0, 3) / 16.0, vec2(8, 11) / 16.0, vec2(2, 1) / 16.0, vec2(10, 9) / 16.0, vec2(12, 15) / 16.0, vec2(4, 7) / 16.0, vec2(14, 13) / 16.0, vec2(6, 5) / 16.0, vec2(3, 0) / 16.0, vec2(11, 8) / 16.0, vec2(1, 2) / 16.0, vec2(9, 10) / 16.0, vec2(15, 12) / 16.0, vec2(7, 4) / 16.0, vec2(13, 14) / 16.0, vec2(5, 6) / 16.0);
	const vec2 otherOffsets[16] = vec2[16](vec2(0.375, 0.4375), vec2(0.625, 0.0625), vec2(0.875, 0.1875), vec2(0.125, 0.0625),
vec2(0.375, 0.6875), vec2(0.875, 0.4375), vec2(0.625, 0.5625), vec2(0.375, 0.9375),
vec2(0.625, 0.3125), vec2(0.125, 0.5625), vec2(0.125, 0.8125), vec2(0.375, 0.1875),
vec2(0.875, 0.9375), vec2(0.875, 0.6875), vec2(0.125, 0.3125), vec2(0.625, 0.8125)
);
	pos.xy -= ((bayerSequenceOffsets[int(mod(frameCounter - backward, 12))] * 2.0 - 1.0) / vec2(viewWidth, viewHeight));
}
#endif

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
  TemporalJitterProjPos(prev_pos, 1);

  vec4 reproj = vec4(uv, 0.0, 1.0);
  TemporalAntiJitterProjPos(reproj, 0);

  vec2 uv1 = prev_pos.st * 0.5 + 0.5;
  if (uv1.x < 0.001 || uv1.x > 0.999 || uv1.y < 0.001 || uv1.y > 0.999) TAA_weight = 1.0;
  vec4 prev_col = texture2D(colortex3, uv1);

  float depth = texture2D(depthtex0, reproj.xy).r;

  float ldepth = linearizeDepth(depth);
  TAA_weight = max(TAA_weight, smoothstep(0.0, distance(prev_pos.z, frag.vpos.z) * 0.01, distance(linearizeDepth(depth), linearizeDepth(prev_col.a))));
  //TAA_weight = max(TAA_weight, min(abs(luma(color) - luma(prev_col.rgb)) * 2.0, 1.0));
  //TAA_weight = max(TAA_weight, smoothstep(0.0, 0.01, distance(prev_vpos.z, linearizeDepth(prev_col.a))));
  //if (depth < 0.5) TAA_weight = 1.0;

  color = mix(prev_col.rgb, color, TAA_weight);
  taa = vec4(color, mix(prev_col.a, depth, TAA_weight));
  #endif

/* DRAWBUFFERS:57 */
  gl_FragData[0] = vec4(color, 0.0);
  gl_FragData[1] = taa;
}
