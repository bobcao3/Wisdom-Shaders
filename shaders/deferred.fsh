#version 420 compatibility
#pragma optimize(on)

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
    ysize += viewSize.y >> 4;
    yoffset += viewSize.y >> 3;
    if (iuv.y <= ysize && iuv.y >= yoffset && iuv.x <= (viewSize.x >> 4)) {
        depth_lod = texelFetch(depthtex0, ((iuv - ivec2(0, yoffset)) << 4) + ivec2(round(16 * jitter)), 0).r;
    }

    vec4 skybox = vec4(0.0);

    if (iuv.y <= (int(viewHeight) >> 3) + 8 && iuv.x <= (int(viewWidth) >> 2) + 8) {
        if (biomeCategory != 16) {
            vec3 dir = project_uv2skybox(vec2(iuv) * invWidthHeight);
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra, 0.0);
        } else {
            skybox = vec4(fromGamma(fogColor), 0.0);
        }
    }

#ifdef CLOUDS
    if (iuv.x >= (int(viewWidth) >> 1) && iuv.x <= (int(viewWidth) >> 1) + (int(viewWidth) >> 2) && iuv.y < int(viewHeight) >> 1)
    {
        ivec2 adj_iuv = iuv;
        adj_iuv.x -= int(viewWidth) >> 1;
        adj_iuv *= ivec2(4, 2);
        
        vec3 proj_pos = getProjPos(adj_iuv, 1.0);
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        vec3 dir = normalize(world_pos);
        vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

        float nseed = fract(texelFetch(colortex1, iuv & 0xFF, 0).r + texelFetch(colortex1, ivec2(frameCounter) & 0xFF, 0).r);

        skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra, nseed);

        vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
        vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
        proj_pos_prev.xyz /= proj_pos_prev.w;

        vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5);
        if (prev_uv.x > 0.0 && prev_uv.x < 1.0 && prev_uv.y > 0.0 && prev_uv.y < 1.0)
        {
            prev_uv = prev_uv * vec2(0.25, 0.5) + vec2(0.5, 0.0) + 0.5 * invWidthHeight;
            prev_uv = clamp(prev_uv, vec2(0.5, 0.0) + invWidthHeight * 0.5, vec2(0.75, 0.5) - invWidthHeight * 2.0);
            skybox = mix(texture(gaux4, prev_uv), skybox, 0.05);
        }
    }
#endif

/* DRAWBUFFERS:67 */
    gl_FragData[0] = vec4(depth_lod, 0.0, 0.0, 0.0);
    gl_FragData[1] = vec4(skybox);
}