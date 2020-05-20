#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;
uniform sampler2D colortex2;

uniform sampler2D shadowtex0;

#include "configs.glsl"

uniform float viewWidth;
uniform float viewHeight;

#include "libs/color.glsl"
#include "libs/taa.glsl"

//#define DEBUG_SHADOWMAP
//#define DEBUG_ADAPTIVE_EXPOSURE

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex0, iuv, 0);

#ifdef DEBUG_SHADOWMAP
    if (iuv.x < shadowMapQuadRes / 2 && iuv.y < shadowMapQuadRes / 2) {
        color = texelFetch(shadowtex0, iuv * 4, 0);
    }
#endif

    float L = 0.0;

    for (int i = 0; i < 4; i++) {
        vec2 loc = WeylNth(i);
        L += texture(colortex2, loc).a;
    }

#ifdef DEBUG_ADAPTIVE_EXPOSURE
    if (iuv.x < viewWidth / 8 && iuv.y < viewHeight / 8) {
        color = vec4(L);
    }
#endif

    float exposure = clamp(1.5 / L, 0.5, 10.0);

    color = toGamma(color * exposure);
    color.rgb = ACESFitted(color.rgb) * 1.4;

    gl_FragColor = clamp(color, 0.0, 1.0);
}