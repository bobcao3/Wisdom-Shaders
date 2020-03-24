#ifndef _INCLUDE_CONFIGS
#define _INCLUDE_CONFIGS

const int RGBA32UI = 0, RGBA16F = 1, RGBA32F = 2;
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA32F;
const int colortex4Format = RGBA32UI;

const float sunPathRotation = -40.0;
const int shadowMapResolution = 2048;
const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);
const float shadowDistance = 16.0;
//const float shadowDistanceRenderMul = 16.0; // 2 4 8 16
const float shadowIntervalSize = 2.0;

const int shadowMapQuadRes = shadowMapResolution / 2;

#endif