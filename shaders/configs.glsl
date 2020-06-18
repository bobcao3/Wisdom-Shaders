#ifndef _INCLUDE_CONFIGS
#define _INCLUDE_CONFIGS

const int RGBA32UI = 0, RGBA16F = 1, R32F = 2, R11F_G11F_B10F = 3;
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
const int colortex2Format = RGBA16F;
const int colortex3Format = R11F_G11F_B10F;
const int colortex4Format = RGBA32UI;
const int colortex5Format = RGBA16F;
const int colortex6Format = R32F;
const int colortex7Format = R11F_G11F_B10F;

const float sunPathRotation = -40.0;
const int shadowMapResolution = 2048;
const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);
const float shadowDistance = 12.0; // [4.0 6.0 8.0 10.0 12.0 16.0 24.0 32.0 48.0  64.0]
const float shadowDistanceRenderMul = 16.0;
const float shadowIntervalSize = 2.0;

const int shadowMapQuadRes = shadowMapResolution / 2;

const bool colortex2Clear = false;

const float ambientOcclusionLevel = 0.0f;

#ifndef MC_RENDER_QUALITY
#define MC_RENDER_QUALITY 1.0
#endif

#ifndef MC_SHADOW_QUALITY
#define MC_SHADOW_QUALITY 1.0
#endif

#endif