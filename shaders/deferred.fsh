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

varying vec3 sunlight;
varying vec3 sunraw;
varying vec3 ambientU;

#include "GlslConfig"

varying vec3 worldLightPosition;

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/atmosphere.glsl"

void main() {
  vec3 color = vec3(0.0);

  if (uv.y < 0.5) {
    vec3 nwpos = project_uv2skybox(uv);

    float mu_s = dot(nwpos, worldLightPosition);
    float mu = abs(mu_s);
    #ifdef CLOUDS_2D
    float cmie = calc_clouds(nwpos * 512.0, cameraPosition);
    color *= 1.0 - cmie;

    float opmu2 = 1. + mu*mu;
    float phaseM = .1193662 * (1. - g2) * opmu2 / ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));
    vec3 sunlight = sunraw * 1.3;
    color += (1.4 * luma(ambientU) + sunlight * phaseM) * cmie;
    #endif

    color += scatter(vec3(0., 25e2 + cameraPosition.y, 0.), nwpos, worldLightPosition, Ra);
  }

/* DRAWBUFFERS:7 */
  gl_FragData[0] = vec4(color, 0.0);
}
