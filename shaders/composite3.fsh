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

uniform float frameTime;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex0, iuv, 0);
    float L = 0.0;

    if (iuv.x < 32 && iuv.y < 32)
    {
        for (int i = 0; i < 4; i++) {
            vec2 loc = WeylNth(int((frameCounter & 0xFF) * 4 + i + iuv.x ^ iuv.y)) * 0.5 + 0.25;
            L += clamp(luma(textureLod(colortex0, loc, 3).rgb), 0.0, 5.0);
        }

        float decay = 0.995;
        const float std_fps = 60.0;
        decay = pow(decay, frameTime * std_fps);

        L = mix(texelFetch(colortex2, iuv, 0).a, L, 1.0 - decay);
    }

/* DRAWBUFFERS:2 */
    gl_FragData[0] = vec4(color.rgb, L);
}