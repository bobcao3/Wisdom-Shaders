#version 420 compatibility
#pragma optimize(on)

#define BUFFERS
#define TRANSFORMATIONS_RESIDUAL
#define VECTORS
#define CLIPPING_PLANE

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"
#include "libs/uniforms.glsl"

uniform float rainStrength;

vec3 get_uniform_hemisphere_weighted(vec2 r) {
    float phi = 2.0 * 3.1415926 * r.y;
    float sqrt_rx = sqrt(r.x);

    return vec3(cos(phi) * sqrt_rx, sin(phi) * sqrt_rx, sqrt(1.0 - r.x));
}

mat3 make_coord_space(vec3 n) {
    vec3 h = n;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
        h.x = 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
        h.y = 1.0;
    else
        h.z = 1.0;

    vec3 y = normalize(cross(h, n));
    vec3 x = normalize(cross(n, y));

    return mat3(x, y, n);
}

#include "libs/raytrace.glsl"

const bool colortex3Clear = false;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite = skyColor * 2.5;

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        float ao = 0.0;

        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        float skyLight = smoothstep(0.04, 1.0, lmcoord.y);
        vec3 L = vec3(0.0);

        //vec3 ray_trace_dir = reflect(normalize(view_pos), normal);
        const int num_sspt_rays = 2;
        const float weight_per_ray = 1.0 / float(num_sspt_rays);

        for (int i = 0; i < num_sspt_rays; i++) {
            float noise_sample = fract(bayer64(iuv));
            vec2 grid_sample = WeylNth(int(noise_sample * (4096 * num_sspt_rays) + (frameCounter & 0xFF) * (4096 * num_sspt_rays) + i));
            grid_sample.x *= 0.8;
            vec3 object_space_sample = get_uniform_hemisphere_weighted(grid_sample);
            vec3 ray_trace_dir = make_coord_space(normal) * object_space_sample;
            //vec3 ray_trace_dir = reflect(normalize(view_pos), normal);

            ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, false, 1.0, 1.4, 0.25);
            if (reflected != ivec2(0)) {
                vec3 radiance = texelFetch(colortex0, reflected, 0).rgb;

                vec3 sampled_vpos = proj2view(getProjPos(ivec2(reflected)));
                vec3 sampled_normal = normalDecode(texelFetch(colortex4, reflected, 0).r);
                vec3 offset = vec3(sampled_vpos - view_pos);
                radiance *= step(0.0, dot(sampled_normal, -ray_trace_dir)) / ((1.0 + dot(offset, offset)) * object_space_sample.z);
                L += radiance;
            } else {
                ao += 1.0;
            }
        }
        
        ao = ao * weight_per_ray;
        L *= weight_per_ray;

        L += skyColor * min(skyLight, ao) * 2.5; // 15000 lux
        
        vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
        vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
        proj_pos_prev.xyz /= proj_pos_prev.w;

        vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5) + 0.5 * invWidthHeight;
        vec4 history = texture(colortex3, prev_uv);
        float mix_weight = 0.05;
        if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) {
            history = vec4(0.0);
            mix_weight = 1.0;
        }

        float history_depth = proj_pos_prev.z * 0.5 + 0.5;
        if (abs(history.a - history_depth) / history_depth > 0.05) {
            mix_weight = 1.0;
        }

        composite = mix(history.rgb, L, mix_weight);
    }

/* DRAWBUFFERS:5 */
    gl_FragData[0] = vec4(composite, depth);
}