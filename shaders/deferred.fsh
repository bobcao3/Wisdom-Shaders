#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

#define VECTORS
#define TRANSFORMATIONS_RESIDUAL
#define TRANSFORMATIONS
#define BUFFERS

#define CLOUDS

#include "/libs/uniforms.glsl"
#include "/libs/taa.glsl"
#include "/libs/atmosphere.glsl"
#include "/libs/transform.glsl"
#include "/libs/color.glsl"

uniform int frameCounter;
uniform int biomeCategory;
uniform vec3 fogColor;

const bool colortex7Clear = false;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec2 jitter = WeylNth(frameCounter);

    float depth_lod = 0.0;

    ivec2 viewSize = ivec2(viewWidth, viewHeight);

    int ysize = viewSize.y >> 1;
    int yoffset = 0;
    if (iuv.y <= ysize && iuv.x <= (viewSize.x >> 1)) {
        depth_lod = texelFetch(depthtex0, (iuv << 1) + ivec2(round(2 * jitter)), 0).r;
    }
    ysize += viewSize.y >> 2;
    yoffset += viewSize.y >> 1;
    if (iuv.y <= ysize && iuv.y >= yoffset && iuv.x <= (viewSize.x >> 2)) {
        depth_lod = texelFetch(depthtex0, ((iuv - ivec2(0, yoffset)) << 2) + ivec2(round(4 * jitter)), 0).r;
    }
    ysize += viewSize.y >> 3;
    yoffset += viewSize.y >> 2;
    if (iuv.y <= ysize && iuv.y >= yoffset && iuv.x <= (viewSize.x >> 3)) {
        depth_lod = texelFetch(depthtex0, ((iuv - ivec2(0, yoffset)) << 3) + ivec2(round(8 * jitter)), 0).r;
    }

    vec4 skybox = texelFetch(gaux4, iuv, 0);

    if (iuv.x <= (int(viewWidth) >> 2) && iuv.y > (int(viewHeight) >> 2))
    {
        vec2 uv = (vec2(iuv) * invWidthHeight - vec2(0.0, 0.5)) * 4.0;
        skybox.rg = clamp(vec2(densitiesMap(uv)), vec2(0.0), vec2(200.0));
        skybox.ba = vec2(0.0);
    }

/* DRAWBUFFERS:67 */
    gl_FragData[0] = vec4(depth_lod, 0.0, 0.0, 0.0);
    gl_FragData[1] = vec4(skybox);
}