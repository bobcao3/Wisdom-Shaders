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

#define BLOOM
#ifdef BLOOM
const float padding = 0.02f;

bool checkBlur(vec2 offset, float scale) {
	return
	(  (uv.s - offset.s + padding < 1.0f / scale + (padding * 2.0f))
	&& (uv.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)) );
}

const float weight[3] = float[] (0.3829, 0.0606, 0.2417);

vec3 LODblur(in int LOD, in vec2 offset) {
	float scale = exp2(LOD);
	vec3 bloom = vec3(0.0);

	float allWeights = 0.0f;

	for (int i = -2; i < 3; i++) {
		for (int j = -2; j < 3; j++) {
			vec2 coord = vec2(i, j) / vec2(viewWidth, viewHeight) * 0.5;
			//d1 = fract(d1 + 0.3117);

			vec2 finalCoord = (uv.st + coord.st - offset.st) * scale;

			vec3 c = clamp(texture2DLod(gaux2, finalCoord, 0.0).rgb, vec3(0.0f), vec3(1.0f)) * weight[abs(i)] * weight[abs(j)];

			bloom += c * smoothstep(0.01, 0.1, luma(c));
		}
	}

	return bloom;
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
  if (abs(depth - prev_col.a) > 0.05) TAA_weight = 1.0;

  color = mix(prev_col.rgb, color, TAA_weight);
  taa = vec4(color, mix(prev_col.a, depth, TAA_weight));
  #endif

/* DRAWBUFFERS:057 */
// bloom
	#ifdef BLOOM
	vec3 blur = vec3(0.0);
	/* LOD 2 */
	float lod = 2.0; vec2 offset = vec2(0.0f);
	if (uv.y < 0.25 + padding * 2.0 + 0.6251 && uv.x < 0.0078125 + 0.25f + 0.100f) {
		if (uv.y > 0.25 + padding) {
			if (checkBlur(offset = vec2(0.0f, 0.3f)     + vec2(0.000f, 0.035f), exp2(lod = 3.0))) { /* LOD 3 */ }
			else if (checkBlur(offset = vec2(0.125f, 0.3f)   + vec2(0.030f, 0.035f), exp2(lod = 4.0))) { /* LOD 4 */ }
			else if (checkBlur(offset = vec2(0.1875f, 0.3f)  + vec2(0.060f, 0.035f), exp2(lod = 5.0))) { /* LOD 5 */ }
			else if (checkBlur(offset = vec2(0.21875f, 0.3f) + vec2(0.090f, 0.035f), exp2(lod = 6.0))) { /* LOD 6 */ }
			else lod = 0.0f;
		} else if (uv.x > 0.25 + padding) lod = 0.0f;
		if (lod == 2.0f) blur = LODblur(int(lod), offset);
	}
	gl_FragData[0] = vec4(blur, 1.0);
	#endif
// TAA
  gl_FragData[1] = vec4(color, 0.0);
  gl_FragData[2] = taa;
}
