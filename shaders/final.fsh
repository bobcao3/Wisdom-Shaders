#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

// uniform sampler2D colortex0;
// uniform sampler2D colortex1;
// uniform sampler2D colortex2;
// uniform sampler2D gaux3;
// uniform sampler2D gaux4;

uniform sampler2D shadowtex0;

#include "/configs.glsl"

#define USE_DES_MAP

#include "/libs/atmosphere.glsl"

// uniform float viewWidth;
// uniform float viewHeight;

// uniform vec2 invWidthHeight;

#include "/libs/color.glsl"
#include "/libs/taa.glsl"

// #define DEBUG_SHADOWMAP
// #define DEBUG_ADAPTIVE_EXPOSURE
// #define DEBUG_DEPTH_LOD

in flat float exposure;

uniform float blindness;
uniform float nightVision;

#define SATURATION 0.0 // [-1.0 -0.95 -0.9 -0.85 -0.8 -0.75 -0.7 -0.65 -0.6 -0.55 -0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

#define BLACKS 0.0 // [-1.0 -0.95 -0.9 -0.85 -0.8 -0.75 -0.7 -0.65 -0.6 -0.55 -0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define SHADOWS 0.0 // [-1.0 -0.95 -0.9 -0.85 -0.8 -0.75 -0.7 -0.65 -0.6 -0.55 -0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define MIDTONES 0.0 // [-1.0 -0.95 -0.9 -0.85 -0.8 -0.75 -0.7 -0.65 -0.6 -0.55 -0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define HIGHLIGHTS 0.0 // [-1.0 -0.95 -0.9 -0.85 -0.8 -0.75 -0.7 -0.65 -0.6 -0.55 -0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define WHITES 0.0 // [-1.0 -0.95 -0.9 -0.85 -0.8 -0.75 -0.7 -0.65 -0.6 -0.55 -0.5 -0.45 -0.4 -0.35 -0.3 -0.25 -0.2 -0.15 -0.1 -0.05 0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

//#define PIXELATE

uniform float aspectRatio;

vec4 sharpened_fetch(sampler2D s, ivec2 iuv, int lod)
{
    vec4 c00 = texelFetchOffset(s, iuv, lod, ivec2(-1, -1));
    vec4 c01 = texelFetchOffset(s, iuv, lod, ivec2(-1,  0));
    vec4 c02 = texelFetchOffset(s, iuv, lod, ivec2(-1,  1));
    vec4 c10 = texelFetchOffset(s, iuv, lod, ivec2( 0, -1));
    vec4 c11 = texelFetchOffset(s, iuv, lod, ivec2( 0,  0));
    vec4 c12 = texelFetchOffset(s, iuv, lod, ivec2( 0,  1));
    vec4 c20 = texelFetchOffset(s, iuv, lod, ivec2( 1, -1));
    vec4 c21 = texelFetchOffset(s, iuv, lod, ivec2( 1,  0));
    vec4 c22 = texelFetchOffset(s, iuv, lod, ivec2( 1,  1));

    #define SHARPEN_STRENGTH 0.15 // [0.0 0.05 0.1 0.15 0.2 0.25 0.3]

    vec4 final = clamp((1.0 + SHARPEN_STRENGTH) * c11 - (SHARPEN_STRENGTH / 6.0) * (c00 * 0.5 + c01 + c02 * 0.5 + c10 + c12 + c20 * 0.5 + c21 + c22 * 0.5), c11 * 0.5, vec4(10.0));

    return final;
}

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st * MC_RENDER_QUALITY);
    vec2 uv = vec2(iuv) * invWidthHeight;

#ifdef PIXELATE
    uv = floor(uv * vec2(aspectRatio * 240.0, 240.0)) / vec2(aspectRatio * 240.0, 240.0);
    iuv = ivec2(uv * vec2(viewWidth, viewHeight));
#endif

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);
    vec3 view_pos = proj2view(proj_pos);
    vec3 world_pos = view2world(view_pos);
    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

    vec4 color = sharpened_fetch(colortex0, iuv, 0);

    color.rgb = pow(color.rgb, vec3(1.0 + max(0.0, blindness - nightVision)));

    float nightVisionStrength = float((iuv.y / 2) % 2 != 0) * max(0.0, nightVision - blindness) * max(0.0, 1.0 - sqrt(length(uv * 2.0 - 1.0)));
    color.rgb = color.rgb + nightVisionStrength * vec3(0.1, 1.0, 0.1) * sqrt(color.rgb);

    color.rgb = saturation(color.rgb, SATURATION * 0.5);

    color = toGamma(color * exposure);

    // color.rgb = texelFetch(gaux4, iuv, 0).rgb;

    // color.rgb = scatter(vec3(0.0, cameraPosition.y, 0.0), normalize(world_pos), world_sun_dir, Ra, 0.1).rgb;

    color.rgb = ACESFitted(color.rgb) * 1.2;

    color.rgb = lumaCurve(color.rgb, BLACKS * 0.25, SHADOWS * 0.25, MIDTONES * 0.25, HIGHLIGHTS * 0.25, WHITES * 0.25);

#ifdef DEBUG_SHADOWMAP
    if (iuv.x < shadowMapQuadRes / 2 && iuv.y < shadowMapQuadRes / 2) {
        color = texelFetch(shadowtex0, iuv * 4, 0);
    }
#endif

#ifdef DEBUG_ADAPTIVE_EXPOSURE
    if (iuv.x < viewWidth / 8 && iuv.y < viewHeight / 8) {
        color = vec4(exposure);
    }
#endif

#ifdef DEBUG_DEPTH_LOD
    color.rgb = vec3(texelFetch(gaux3, iuv, 0).r);
#endif

    gl_FragColor = color;
}