#version 430 compatibility
#pragma optimize(on)

#define NORMAL_MAPPING
#define RAIN_PUDDLES
#define POM
// #define SMOOTH_TEXTURE

#define UINT_BUFFER
#include "libs/gbuffers.frag.glsl"
#include "programs/textured.glsl"