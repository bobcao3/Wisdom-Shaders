#ifndef _INCLUDE_CONFIGS
#define _INCLUDE_CONFIGS

/*
const int colortex0Format = R11F_G11F_B10F;
const int colortex1Format = R11F_G11F_B10F;
const int colortex2Format = RGBA16F;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGB32UI;
const int colortex5Format = R11F_G11F_B10F;
const int colortex6Format = R32F;
const int colortex7Format = RGBA16F;
*/

const float sunPathRotation = -40.0;
const int shadowMapResolution = 2048; // [512 768 1024 1512 2048 3200 4096]
const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);
const float shadowDistance = 12.0; // [4.0 6.0 8.0 10.0 12.0 16.0 24.0 32.0 48.0 64.0]
const float shadowDistanceRenderMul = 16.0;
const float shadowIntervalSize = 1.0;

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


#define PATREONS PT0 // [PT0 PT1 PT2 PT3 PT4 PT5 PT6 PT7 PT8]