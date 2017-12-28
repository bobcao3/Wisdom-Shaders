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

#ifndef _INCLUDE_COMPAT
#define _INCLUDE_COMPAT

#extension GL_ARB_shader_texture_lod : require

// GPU Shader 4
#ifdef MC_GL_EXT_gpu_shader4

#extension GL_EXT_gpu_shader4 : require
#define HIGH_LEVEL_SHADER

#endif

// Half float support
#ifdef MC_GL_AMD_shader_half_float
#extension GL_AMD_shader_half_float : require
#else

	#define float16_t float
	#define f16vec2 vec2
	#define f16vec3 vec3
	#define f16vec4 vec4
	#define f16mat2 mat2
	#define f16mat3 mat3
	#define f16mat4 mat4
	#define HF f

#endif

#define sampler2D_color sampler2D

// GPU Shader 5
#ifdef MC_GL_ARB_gpu_shader5
#extension GL_ARB_gpu_shader5 : require
#else
#define fma(a,b,c) ((a)*(b)+c)
#endif

// Texture gather
#ifdef MC_GL_ARB_texture_gather
#extension GL_ARB_texture_gather : require
#else

#ifndef VIEW_WIDTH
#define VIEW_WIDTH
uniform float viewWidth;                        // viewWidth
uniform float viewHeight;                       // viewHeight
vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);
#endif

vec4 textureGather(sampler2D sampler, vec2 coord) {
  vec2 c = coord * vec2(viewWidth, viewHeight);
  c = round(c) * pix;
  return vec4(
    texture2D(sampler, c + vec2(.0,pixel.y)     ).r,
    texture2D(sampler, c + vec2(pixel.x,pixel.y)).r,
    texture2D(sampler, c + vec2(.0,pixel.y)     ).r,
    texture2D(sampler, c                        ).r
  );
}

vec4 textureGatherOffset(sampler2D sampler, vec2 coord, ivec2 offset) {
  vec2 c = coord * vec2(viewWidth, viewHeight);
  c = (round(c) + vec2(offset)) * pixel;
  return vec4(
    texture2D(sampler, c + vec2(.0,pixel.y)     ).r,
    texture2D(sampler, c + vec2(pixel.x,pixel.y)).r,
    texture2D(sampler, c + vec2(.0,pixel.y)     ).r,
    texture2D(sampler, c                        ).r
  );
}
#endif

#define sum4(x) (dot(vec4(1.0), x))
#define sum3(x) (dot(vec3(1.0), x))
#define sum2(x) (x.x + x.y)

#endif
