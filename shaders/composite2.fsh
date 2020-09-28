#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

#include "libs/taa.glsl"
#include "libs/color.glsl"

uniform int frameCounter;

const bool colortex0MipmapEnabled = true;

uniform vec2 invWidthHeight;

uniform float frameTime;

uniform float viewWidth;
uniform float viewHeight;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    
    vec4 color = texelFetch(colortex0, iuv, 0);
    float L = 0.0;

    if (iuv.x < 8 && iuv.y < 8)
    {
        for (int i = 0; i < 8; i++)
        {
            vec2 loc = WeylNth(int((frameCounter & 0xFFFF) * 8 + i + iuv.x ^ iuv.y)) * 0.5 + 0.25;

            L += clamp(luma(texelFetch(colortex0, ivec2(vec2(viewWidth, viewHeight) * loc), 0).rgb), 0.0, 10.0);
        }

        L *= 0.125;

        float decay = 0.995;
        const float std_fps = 60.0;
        decay = pow(decay, frameTime * std_fps);

        L = mix(texelFetch(colortex2, iuv, 0).a, L, 1.0 - decay);
    }

/* DRAWBUFFERS:2 */
    gl_FragData[0] = vec4(color.rgb, L);
}