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

    vec2 jitter = WeylNth(frameCounter) * 2.0; 

    float depth_lod0 = 0.0;//texelFetch(depthtex0, iuv, 0).r;
    float depth_lod1 = 0.0;
    float depth_lod2 = 0.0;
    float depth_lod3 = 0.0;

    ivec2 viewSize = ivec2(viewWidth, viewHeight);

    if (iuv.y <= (viewSize.y >> 1) && iuv.x <= (viewSize.x >> 1)) {
        depth_lod1 = texelFetch(depthtex0, (iuv << 1) + ivec2(round(1 * jitter)), 0).r;
    }
    if (iuv.y <= (viewSize.y >> 2) && iuv.x <= (viewSize.x >> 2)) {
        depth_lod2 = texelFetch(depthtex0, (iuv << 2) + ivec2(round(2 * jitter)), 0).r;
    }
    if (iuv.y <= (viewSize.y >> 3) && iuv.x <= (viewSize.x >> 3)) {
        depth_lod3 = texelFetch(depthtex0, (iuv << 3) + ivec2(round(4 * jitter)), 0).r;
    }

    vec3 skybox = vec3(0.0);

    if (iuv.y <= (int(viewHeight) >> 2) && iuv.x <= (int(viewWidth) >> 1)) {
        if (biomeCategory != 16) {
            vec3 dir = project_uv2skybox(vec2(iuv) * invWidthHeight);
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra);
        } else {
            skybox = fromGamma(fogColor);
        }
    }

/* DRAWBUFFERS:67 */
    gl_FragData[0] = vec4(depth_lod0, depth_lod1, depth_lod2, depth_lod3);
    gl_FragData[1] = vec4(skybox, 1.0);
}