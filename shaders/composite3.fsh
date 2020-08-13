#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex1;

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

    if (iuv.x <= viewWidth * 0.875 && iuv.x >= viewWidth * 0.625 && iuv.y < viewHeight * 0.25)
    {
        ivec2 uv = iuv - ivec2(viewWidth * 0.625, 0);
        uv *= 2;

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

/* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(bloom, 1.0);
}