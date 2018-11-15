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
#include "libs/vectors.glsl"

#define FXAA
#ifdef FXAA
#include "libs/color.glsl"
#include "libs/fxaa.glsl"
#endif

#define TAA

void main() {
/* DRAWBUFFERS:53 */
#ifdef FXAA
	vec4 color = vec4(fxaa(gaux2, uv + 0.5 / vec2(viewWidth, viewHeight), uv, vec2(viewWidth, viewHeight)), 1.0);
#else
	vec4 color = vec4(texture2D(gaux2, uv).rgb, 1.0);
#endif
#ifdef TAA
	vec3 wpos = vec3(gbufferModelViewInverse * fetch_vpos(uv, depthtex0));
	vec4 prev_pos = gbufferPreviousModelView * vec4(wpos - previousCameraPosition + cameraPosition, 1.0);
    prev_pos = gbufferPreviousProjection * prev_pos;
    prev_pos /= prev_pos.w;
    vec2 prev_uv = fma(prev_pos.st, vec2(0.5f), vec2(0.5f));
    float weight = 0.6;
    if (clamp(prev_uv, vec2(0.0), vec2(1.0)) != prev_uv) weight = 0.0;
    vec4 prev_color = texture2D(colortex3, prev_uv);

    weight *= max(0.0, 1.0 - distance(linearizeDepth(prev_color.a), linearizeDepth(fma(prev_pos.z, 0.5, 0.5))) * far * 4.0);
    prev_color.rgb = clamp(prev_color.rgb, vec3(0.0), vec3(1.0));

    color.rgb = mix(color.rgb, prev_color.rgb, weight);
#endif
	gl_FragData[0] = color;
#ifdef TAA
	gl_FragData[1] = vec4(color.rgb, texture2D(depthtex0, uv).r);
#endif
}
