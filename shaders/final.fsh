#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D shadowtex0;

#include "configs.glsl"

uniform float viewWidth;
uniform float viewHeight;

uniform vec2 invWidthHeight;

#include "libs/color.glsl"
#include "libs/taa.glsl"

// #define DEBUG_SHADOWMAP
// #define DEBUG_ADAPTIVE_EXPOSURE
// #define DEBUG_DEPTH_LOD

in flat float exposure;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st * MC_RENDER_QUALITY);

    vec4 color = texelFetch(colortex0, iuv, 0);

    color = toGamma(color * exposure);
    color.rgb = ACESFitted(color.rgb) * 1.4;

#ifdef DEBUG_SHADOWMAP
    if (iuv.x < shadowMapQuadRes / 2 && iuv.y < shadowMapQuadRes / 2) {
        color = texelFetch(shadowtex0, iuv * 4, 0);
    }
#endif

#ifdef DEBUG_ADAPTIVE_EXPOSURE
    if (iuv.x < viewWidth / 8 && iuv.y < viewHeight / 8) {
        color = vec4(L);
    }
#endif

#ifdef DEBUG_DEPTH_LOD
    color.rgb = vec3(texelFetch(gaux3, iuv, 0).r);
#endif

    gl_FragColor = clamp(color, 0.0, 1.0);
}