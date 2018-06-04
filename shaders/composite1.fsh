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

varying vec3 worldLightPosition;

const bool gaux4Clear = false;
const bool colortex0MipmapEnabled = true;

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  if (!mask.is_sky) {

    float fog_coord = min(length(frag.wpos) / (1024.0 - wetness * 512.0), 1.0);
    color *= 1.0 - fog_coord * 0.8;
    vec3 direction = normalize(frag.wpos);

    // Blur and collect scattering
    float scatteram  = sum4(textureGather      (colortex0, uv              ));
          scatteram += sum4(textureGatherOffset(colortex0, uv, ivec2(-1, 0)));
          scatteram += sum4(textureGatherOffset(colortex0, uv, ivec2(-1,-1)));
          scatteram += sum4(textureGatherOffset(colortex0, uv, ivec2( 0,-1)));
          scatteram *= 0.0625;
    color += scatter(vec3(0., 25e2 + cameraPosition.y, 0.), direction, worldLightPosition, fog_coord * 600e3) * scatteram;
  }

  if (isEyeInWater == 1 && !mask.is_water) {
    float dist_diff_N = min(1.0, frag.cdepth * 0.0625);             // Distance clamped (0.0 ~ 1.0)

	float absorption = 2.0 / (dist_diff_N + 1.0) - 1.0;             // Water absorption factor
	vec3 watercolor = color
		*  pow(vec3(absorption), vec3(2.0, 0.8, 1.0))                 // Water absorption color
		* (abs(worldLightPosition.y) * 0.8 + 0.2);                   // Scatter-in factor
	float light_att = float(eyeBrightnessSmooth.y) / 240.0;
    const vec3 waterfogcolor = vec3(0.35,0.9,0.83) * 1.7;
	vec3 waterfog = (max(luma(ambientU), 0.0) * light_att) * waterfogcolor;

    color = mix(waterfog, watercolor, absorption);
  }

/* DRAWBUFFERS:357 */
  gl_FragData[0] = texture2D(gaux4, uv); // TXAA
  gl_FragData[1] = vec4(color, 1.0);
  gl_FragData[2] = vec4(color, 1.0);
}
