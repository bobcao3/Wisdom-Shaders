#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;
uniform sampler2D colortex2;
uniform sampler2D gaux3;

uniform sampler2D shadowtex0;

#include "configs.glsl"

uniform float viewWidth;
uniform float viewHeight;

#include "libs/color.glsl"
#include "libs/taa.glsl"

// #define DEBUG_SHADOWMAP
// #define DEBUG_ADAPTIVE_EXPOSURE

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st * MC_RENDER_QUALITY);

    vec4 color = texelFetch(colortex0, iuv, 0);

    float L = 0.0;

    for (int i = 0; i < 4; i++) {
        vec2 loc = WeylNth(i);
        L += texture(colortex2, loc).a;
    }

    float exposure = clamp(3.0 / L, 0.1, 10.0);

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

    gl_FragColor = clamp(color, 0.0, 1.0);
}