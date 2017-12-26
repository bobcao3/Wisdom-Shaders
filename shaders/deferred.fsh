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
LightSourcePBR sun;
LightSourceHarmonics ambient;

#include "libs/atmosphere.glsl"

varying vec3 sunLight;
varying vec3 ambientU;
varying vec3 ambient0;
varying vec3 ambient1;
varying vec3 ambient2;
varying vec3 ambient3;
varying vec3 ambientD;

void main() {
  vec3 color = vec3(0.0);

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  vec3 worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);

  if (!mask.is_sky) {
    sun.light.color = sunLight;
    sun.L = lightPosition;

    vec3 wN = mat3(gbufferModelViewInverse) * frag.N;

    float thickness = 1.0, shade = 0.0;
    shade = light_fetch_shadow(shadowtex1, wpos2shadowpos(frag.wpos + 0.05 * wN), thickness);
    sun.light.attenuation = 1.0 - shade;

    ambient.attenuation = light_mclightmap_simulated_GI(frag.skylight);
    #ifdef DIRECTIONAL_LIGHTMAP
    ambient.attenuation *= lightmap_normals(frag.N, frag.skylight, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0));
    #endif

    float ao = 1.0;
    #ifdef WAO
    ao = calcAO(frag.N, frag.cdepth, frag.vpos, uv);
    #endif

    ambient.color0 = ambientU * ao;
    ambient.color1 = ambient0 * ao;
    ambient.color2 = ambient1 * ao;
    ambient.color3 = ambient2 * ao;
    ambient.color4 = ambient3 * ao;
    ambient.color5 = ambientD * ao;

    color = light_calc_PBR(sun, frag, mask.is_plant ? thickness : 
1.0) + light_calc_diffuse_harmonics(ambient, frag, wN);

    color = mix(color, frag.albedo, frag.emmisive);
  } else {
    vec3 nwpos = normalize(frag.wpos);
    color = texture2D(colortex0, uv).rgb;
    color += scatter(vec3(0., 25e2 + cameraPosition.y, 0.), nwpos, worldLightPosition, Ra);

    if (mask.is_sky_object) color += vec3(0.4);
  }

/* DRAWBUFFERS:5 */
  gl_FragData[0] = vec4(color, 0.0);
}
