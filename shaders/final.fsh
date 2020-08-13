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

#include "libs/bicubic.glsl"

in flat float exposure;

vec3 getBloom(ivec2 iuv)
{
    vec2 uv = vec2(iuv) * invWidthHeight;

    vec3 bloom = vec3(0.0);

    vec2 offset = vec2(invWidthHeight.x, -invWidthHeight.y) * 0.5;

    // bloom += texture_Bicubic(colortex1, uv * 0.5 - invWidthHeight * 0.5 + offset).rgb;
    bloom += texture_Bicubic(colortex1, uv * 0.25 + vec2(0.625, 0.0) + offset).rgb;
    bloom += texture_Bicubic(colortex1, uv * 0.125 + vec2(0.625, 0.375) + offset).rgb;
    bloom += texture_Bicubic(colortex1, uv * 0.0625 + vec2(0.8125, 0.375) + offset).rgb;
    bloom += texture_Bicubic(colortex1, uv * 0.03125 + vec2(0.8125, 0.46875) + offset).rgb;

    bloom *= 0.02;

    return bloom;
}

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st * MC_RENDER_QUALITY);

    vec4 color = texelFetch(colortex0, iuv, 0);

    // color.rgb = texelFetch(colortex1, iuv, 0).rgb;

    color.rgb += getBloom(iuv);

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