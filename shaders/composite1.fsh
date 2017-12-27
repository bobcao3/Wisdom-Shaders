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
#include "libs/Lighting.frag"

Mask mask;
Material frag;

#define CrespecularRays
#include "libs/atmosphere.glsl"

varying vec3 sunLight;
varying vec3 ambientU;

const bool gaux4Clear = false;
const bool colortex0MipmapEnabled = true;

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  if (!mask.is_sky) {
    vec3 worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);

    float fog_coord = min(length(frag.wpos) / 1024.0, 1.0);
    color *= 1.0 - fog_coord * 0.8;
    vec3 direction = normalize(frag.wpos);

    // Blur and collect scattering
    float scatter  = sum4(textureGather      (colortex0, uv              ));
          scatter += sum4(textureGatherOffset(colortex0, uv, ivec2(-1, 0)));
          scatter += sum4(textureGatherOffset(colortex0, uv, ivec2(-1,-1)));
          scatter += sum4(textureGatherOffset(colortex0, uv, ivec2( 0,-1)));
          scatter *= 0.0625;
    color += scatter(vec3(0., 25e2 + cameraPosition.y, 0.), direction, worldLightPosition, fog_coord * 600e3) * scatter;
  }

/* DRAWBUFFERS:357 */
  gl_FragData[0] = texture2D(gaux4, uv); // TXAA
  gl_FragData[1] = vec4(color, 1.0);
  gl_FragData[2] = vec4(color, 1.0);
}
