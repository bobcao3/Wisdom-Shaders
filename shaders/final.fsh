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

varying vec2 uv;

const int RGBA8 = 0, R11_G11_B10 = 1, R8 = 2, RGBA16F = 3, RGBA16 = 4, RG16 = 5;

const int colortex0Format = RGBA8;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA16;
const int colortex3Format = RGBA8;
const int gaux1Format = RGBA16;
const int gaux2Format = R11_G11_B10;
const int gaux3Format = RGBA16F;
const int gaux4Format = RGBA8;

#include "GlslConfig"

#define VIGNETTE

#include "libs/uniforms.glsl"
#include "libs/color.glsl"

uniform float screenBrightness;

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;

  ACEStonemap(color, screenBrightness * 0.5 + 1.0);

  gl_FragColor = vec4(toGamma(color),1.0);
}
