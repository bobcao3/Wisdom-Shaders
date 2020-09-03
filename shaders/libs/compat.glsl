#ifndef _INCLUDE_COMPAT
#define _INCLUDE_COMPAT

#ifdef VERTEX
#define INOUT out
#else
#define INOUT in
#endif

#define USE_HALF

#if (defined(USE_HALF) && defined(MC_GL_NV_gpu_shader5))

#extension GL_NV_gpu_shader5 : enable

#elif (defined(USE_HALF) && defined(MC_GL_AMD_gpu_shader_half_float))

#extension GL_AMD_gpu_shader_half_float : enable

#else

#define float32_t float
#define f32vec2 vec2
#define f32vec3 vec3
#define f32vec4 vec4
#define float16_t float
#define f16vec2 vec2
#define f16vec3 vec3
#define f16vec4 vec4
#define int8_t int
#define int16_t int
#define int32_t int

#endif


#endif