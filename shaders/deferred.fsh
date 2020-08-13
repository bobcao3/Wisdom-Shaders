#version 420 compatibility
#pragma optimize(on)

#define VECTORS
#define TRANSFORMATIONS
#define BUFFERS

#include "libs/uniforms.glsl"
#include "libs/taa.glsl"
#include "libs/atmosphere.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"

uniform int frameCounter;
uniform int biomeCategory;
uniform vec3 fogColor;

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
    ysize += viewSize.y >> 4;
    yoffset += viewSize.y >> 3;
    if (iuv.y <= ysize && iuv.y >= yoffset && iuv.x <= (viewSize.x >> 4)) {
        depth_lod = texelFetch(depthtex0, ((iuv - ivec2(0, yoffset)) << 4) + ivec2(round(16 * jitter)), 0).r;
    }

    vec3 skybox = vec3(0.0);

    if (iuv.y <= (int(viewHeight) >> 3) + 8 && iuv.x <= (int(viewWidth) >> 2) + 8) {
        if (biomeCategory != 16) {
            vec3 dir = project_uv2skybox(vec2(iuv) * invWidthHeight);
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra);
        } else {
            skybox = fromGamma(fogColor);
        }
    }

/* DRAWBUFFERS:67 */
    gl_FragData[0] = vec4(depth_lod, 0.0, 0.0, 0.0);
    gl_FragData[1] = vec4(skybox, 1.0);
}