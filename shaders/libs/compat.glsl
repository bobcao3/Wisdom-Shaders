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

#endif
