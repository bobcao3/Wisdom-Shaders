#ifndef _INCLUDE_COMPAT
#define _INCLUDE_COMPAT

#extension GL_ARB_shader_texture_lod : require

// GPU Shader 4
#ifdef MC_GL_EXT_gpu_shader4

#extension GL_EXT_gpu_shader4 : require
#define HIGH_LEVEL_SHADER

#endif

/*
Nvidia tells some how the wrong thing that the truth is that it does not work

// Half float support
#ifndef __GLSL_CG_DATA_TYPES

	#if defined(MC_GL_NV_half_float)
		#extension GL_NV_half_float : require
	#elif defined(MC_GL_AMD_gpu_shader_half_float)
		#extension GL_AMD_gpu_shader_half_float : require
	#else

		#define half float
		#define half2 vec2
		#define half3 vec3
		#define half4 vec4

	#endif

#endif
*/

#define sampler2D_color sampler2D

#endif
