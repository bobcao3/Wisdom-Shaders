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

#define WAO
#define WAO_HIGH

#define SHADOW_COLOR
//#define GI
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

const bool colortex3Clear = false;

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

    vec4 prev_pos = gbufferPreviousModelView * vec4(frag.wpos - previousCameraPosition + cameraPosition, 1.0);
    prev_pos = gbufferPreviousProjection * prev_pos;
    prev_pos /= prev_pos.w;
    vec2 prev_uv = fma(prev_pos.st, vec2(0.5f), vec2(0.5f));
    float weight = 0.82;
    if (clamp(prev_uv, vec2(0.0), vec2(1.0)) != prev_uv) weight = 0.0;
    vec4 prev_color = texture2D(colortex3, prev_uv);

    weight *= max(0.0, 1.0 - distance(linearizeDepth(prev_color.a), linearizeDepth(fma(prev_pos.z, 0.5, 0.5))) * far * 2.0);

    gi = mix(gi, texture2D(colortex3, prev_uv).rgb, weight);
  	#endif
  }

/* DRAWBUFFERS:536 */
  gl_FragData[0] = vec4(color, 0.0);
  #ifdef GI
  gl_FragData[1] = vec4(gi, texture2D(depthtex0, uv).r);
  gl_FragData[2] = vec4(gi, 0.0);
  #endif
}
