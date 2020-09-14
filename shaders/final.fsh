#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

// uniform sampler2D colortex0;
// uniform sampler2D colortex1;
// uniform sampler2D colortex2;
// uniform sampler2D gaux3;
// uniform sampler2D gaux4;

// uniform sampler2D shadowtex0;

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

#define SATURATION 0.0 // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]

#define BLACKS 0.0 // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]
#define SHADOWS 0.0 // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]
#define MIDTONES 0.0 // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]
#define HIGHLIGHTS 0.0 // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]
#define WHITES 0.0 // [-1.0 -0.75 -0.5 -0.25 0.0 0.25 0.5 0.75 1.0]

//#define PIXELATE

uniform float aspectRatio;

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

    vec4 color = texelFetch(colortex0, iuv, 0);

    color.rgb = pow(color.rgb, vec3(1.0 + max(0.0, blindness - nightVision)));

    float nightVisionStrength = float((iuv.y / 2) % 2 != 0) * max(0.0, nightVision - blindness) * max(0.0, 1.0 - pow(length(uv * 2.0 - 1.0), 0.5));
    color.rgb = color.rgb + nightVisionStrength * vec3(0.1, 1.0, 0.1) * pow(color.rgb, vec3(1.0 / 2.0));

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
        color = vec4(L);
    }
#endif

#ifdef DEBUG_DEPTH_LOD
    color.rgb = vec3(texelFetch(gaux3, iuv, 0).r);
#endif

    gl_FragColor = clamp(color, 0.0, 1.0);
}