#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;

const bool colortex2Clear = false;

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

    vec3 bloom = vec3(0.0);

    if (iuv.x < viewWidth * 0.5 && iuv.y < viewHeight * 0.5)
    {
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2(-2,  0)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 2,  0)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 0,  2)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 0, -2)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2(-2, -2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 2,  2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2(-2,  2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 2, -2)).rgb * 0.0625;
        bloom += texelFetch(colortex0, iuv * 2, 0).rgb * 0.25;
    }

/* DRAWBUFFERS:12 */
    gl_FragData[0] = vec4(bloom, L);
    gl_FragData[1] = vec4(color.rgb, L);
}