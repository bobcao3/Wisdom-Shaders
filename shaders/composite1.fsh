#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;
uniform sampler2D colortex2;

const bool colortex2Clear = false;

#include "libs/taa.glsl"
#include "libs/color.glsl"

uniform int frameCounter;

const bool colortex0MipmapEnabled = true;

uniform vec2 invWidthHeight;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex0, iuv, 0);
    float L = 0.0;

    for (int i = 0; i < 4; i++) {
        vec2 loc = WeylNth(int((frameCounter & 0xFF) * 4 + i + iuv.x ^ iuv.y)) * 0.5 + 0.25;
        L += luma(textureLod(colortex0, loc, 3).rgb);
    }

    L = mix(texelFetch(colortex2, iuv, 0).a, L, 0.005);

/* DRAWBUFFERS:2 */
    gl_FragData[0] = vec4(color.rgb, L);
}