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
