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

#include "libs/uniforms.glsl"

#define FXAA
#ifdef FXAA
#include "libs/color.glsl"
#include "libs/fxaa.glsl"
#endif

void main() {
/* DRAWBUFFERS:5 */
#ifdef FXAA
	gl_FragData[0] = vec4(fxaa(gaux2, uv + 0.5 / vec2(viewWidth, viewHeight), uv, vec2(viewWidth, viewHeight)), 1.0);
#endif
}
