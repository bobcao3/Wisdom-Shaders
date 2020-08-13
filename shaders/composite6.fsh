#version 420 compatibility
#pragma optimize(on)

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

    vec3 bloom = vec3(0.0);

    if (iuv.x <= viewWidth * 0.875 && iuv.x >= viewWidth * 0.8125 && iuv.y <= viewHeight * 0.5 && iuv.y >= viewHeight * 0.46875)
    {
        ivec2 uv = iuv - ivec2(viewWidth * 0.8125, viewHeight * 0.46875);
        uv *= 2;
        uv += ivec2(viewWidth * 0.8125, viewHeight * 0.375);

        bloom += texelFetchOffset(colortex1, uv, 0, ivec2(-2,  0)).rgb * 0.125;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2( 2,  0)).rgb * 0.125;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2( 0,  2)).rgb * 0.125;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2( 0, -2)).rgb * 0.125;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2(-2, -2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2( 2,  2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2(-2,  2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex1, uv, 0, ivec2( 2, -2)).rgb * 0.0625;
        bloom += texelFetch(colortex1, uv, 0).rgb * 0.25;
    }
    else
    {
        bloom = texelFetch(colortex1, iuv, 0).rgb;
    }
    
    vec4 color = texelFetch(colortex0, iuv, 0);
    float L = 0.0;

    if (iuv.x < 8 && iuv.y < 8)
    {
        vec2 loc = WeylNth(int((frameCounter & 0xFF) * 4 + iuv.x ^ iuv.y)) * 0.5 + 0.25;
        loc *= 0.0625;

        L = clamp(luma(texelFetch(colortex1, ivec2(viewWidth * (loc.x + 0.8125), viewHeight * (loc.y + 0.375)), 0).rgb), 0.0, 10.0);

        float decay = 0.99;
        const float std_fps = 60.0;
        decay = pow(decay, frameTime * std_fps);

        L = mix(texelFetch(colortex2, iuv, 0).a, L, 1.0 - decay);
    }

/* DRAWBUFFERS:12 */
    gl_FragData[0] = vec4(bloom, 1.0);
    gl_FragData[1] = vec4(color.rgb, L);
}