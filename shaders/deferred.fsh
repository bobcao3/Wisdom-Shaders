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
#define WAO_HIGH

#define SHADOW_COLOR
#define GI
#if defined(GI) && !defined(SHADOW_COLOR)
uniform sampler2D shadowcolor0;
#endif

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

varying vec3 worldLightPosition;

void main() {
  vec3 color = vec3(0.0);
  #ifdef GI
  vec3 gi = vec3(0.0);
  #endif

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  if (!mask.is_sky) {
    #ifdef WAO
    color.r = calcAO(frag.N, frag.cdepth, frag.vpos, uv);
    #endif
	
	#ifdef GI
	vec3 wN = mat3(gbufferModelViewInverse) * frag.N;
	vec3 spos = wpos2shadowpos(frag.wpos - wN * 0.07 * frag.cdepth);
	gi = calcGI(shadowtex1, shadowcolor0, spos, wN);
	#endif
  }

/* DRAWBUFFERS:53 */
  gl_FragData[0] = vec4(color, 0.0);
  #ifdef GI
  gl_FragData[1] = vec4(gi, 0.0);
  #endif
}
