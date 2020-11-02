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

    vec4 skybox = texelFetch(gaux4, iuv, 0);

    if (iuv.y <= (int(viewHeight) >> 3) + 8 && iuv.x <= (int(viewWidth) >> 2) + 8) {
        if (biomeCategory != 16) {
            vec3 dir = project_uv2skybox(vec2(iuv) * invWidthHeight);
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra, 0.1, cameraPosition);
        } else {
            skybox = vec4(fromGamma(fogColor), 0.0);
        }
    }

#ifdef CLOUDS
    if (biomeCategory == 16) {
        skybox = vec4(fromGamma(fogColor), 0.0);
    }
    else if (iuv.x >= (int(viewWidth) >> 1) && iuv.y < (int(viewHeight) >> 1) + 3)
    // else if (iuv.x >= (int(viewWidth) >> 1) && iuv.x <= (int(viewWidth) >> 1) + (int(viewWidth) >> 2) && iuv.y < (int(viewHeight) >> 1) + 3)
    {
        ivec2 adj_iuv = iuv;
        adj_iuv.x -= int(viewWidth) >> 1;
        adj_iuv *= ivec2(2, 2);

        bool shouldRender = false;
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(-4, 0)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(-2, 0)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(2, 0)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(4, 0)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(-4, 1)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(-2, 1)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(2, 1)).r >= 1.0);
        shouldRender = shouldRender || (texelFetchOffset(depthtex0, adj_iuv, 0, ivec2(4, 1)).r >= 1.0);

        if (shouldRender)
        {
            vec3 proj_pos = getProjPos(adj_iuv, 1.0);
            vec3 view_pos = proj2view(proj_pos);
            vec3 world_pos = view2world(view_pos);

            vec3 dir = normalize(world_pos);
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

            float nseed = fract(texelFetch(colortex1, iuv & 0xFF, 0).r + texelFetch(colortex1, ivec2(frameCounter & 0xFF), 0).r);

#ifdef CLOUDS
            skybox = scatterClouds(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra, nseed, cameraPosition + world_pos);
#else
            skybox = scatter(vec3(0.0, cameraPosition.y, 0.0), dir, world_sun_dir, Ra, nseed, cameraPosition + world_pos);
#endif

            vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
            vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
            proj_pos_prev.xyz /= proj_pos_prev.w;

            vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5);
            if (prev_uv.x > 0.0 && prev_uv.x < 1.0 && prev_uv.y > 0.0 && prev_uv.y < 1.0)
            {
                prev_uv = prev_uv * vec2(0.5, 0.5) + vec2(0.5, 0.0) + 0.5 * invWidthHeight;
                prev_uv = clamp(prev_uv, vec2(0.5, 0.0) + invWidthHeight * 0.5, vec2(1.0, 0.5) - invWidthHeight * 2.0);
                ivec2 iprev_uv = ivec2(prev_uv * vec2(viewWidth, viewHeight));

                vec4 prevSkyBox00 = texelFetchOffset(gaux4, iprev_uv, 0, ivec2(0, 0));
                vec4 prevSkyBox01 = texelFetchOffset(gaux4, iprev_uv, 0, ivec2(0, 1));
                vec4 prevSkyBox10 = texelFetchOffset(gaux4, iprev_uv, 0, ivec2(1, 0));
                vec4 prevSkyBox11 = texelFetchOffset(gaux4, iprev_uv, 0, ivec2(1, 1));

                if (dot(prevSkyBox00, vec4(1.0)) > 0.0
                 && dot(prevSkyBox01, vec4(1.0)) > 0.0
                 && dot(prevSkyBox10, vec4(1.0)) > 0.0
                 && dot(prevSkyBox11, vec4(1.0)) > 0.0)
                {
                    skybox = mix(texture(gaux4, prev_uv), skybox, 0.1);
                }
            }
        }
        else
        {
            skybox = vec4(0.0);
        }
    }
#endif

/* DRAWBUFFERS:7 */
    gl_FragData[0] = vec4(skybox);
}