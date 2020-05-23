#version 420 compatibility
#pragma optimize(on)

#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"

#define VECTORS
#define CLIPPING_PLANE
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

ivec2 raytrace(in vec3 vpos, in vec2 iuv, in vec3 dir, bool checkNormals) {
    const float maxDistance = 1.0;
    float rayLength = ((vpos.z + dir.z * maxDistance) > near) ? (near - vpos.z) / dir.z : maxDistance;

    vec3 vpos_target = vpos + dir * rayLength;

    vec4 start_proj_pos = gbufferProjection * vec4(vpos, 1.0);
    vec4 target_proj_pos = gbufferProjection * vec4(vpos_target, 1.0);

    float k0 = 1.0 / start_proj_pos.w;
    float k1 = 1.0 / target_proj_pos.w;

    vec3 P0 = start_proj_pos.xyz * k0;
    vec3 P1 = target_proj_pos.xyz * k1;

    vec2 ZW = vec2(vpos.z * k0, k0);
    vec2 dZW = vec2(vpos_target.z * k1 - vpos.z * k0, k1 - k0);

    vec2 uv_dir = (P1.st - P0.st) * 0.5;
    uv_dir *= vec2(viewWidth, viewHeight);

    float invdx = 1.0;

    if (abs(uv_dir.x) > abs(uv_dir.y)) {
        invdx = 1.0 / abs(uv_dir.x);
        uv_dir = vec2(sign(uv_dir.x), uv_dir.y * invdx);
    } else {
        invdx = 1.0 / abs(uv_dir.y);
        uv_dir = vec2(uv_dir.x * invdx, sign(uv_dir.y));
    }

    float stride = 1.0;//(viewHeight - viewHeight * min(0.96, -vpos.z * 0.001)) / 32.0;
    float dither = bayer64(iuv + (frameCounter & 0xF));

    uv_dir *= stride;
    dZW *= invdx * stride;

    float zThickness = 0.0;//1.0 + (-vpos.z * 0.5);

    ivec2 hit = ivec2(0);

    float last_z = 0.0;

    float z_prev = (ZW.x + dZW.x * (dither + 0.5)) / (ZW.y + dZW.y * (dither + 0.5));
    for (int i = 0; i < 16; i++) {
        iuv += uv_dir;
        ZW += dZW;

        vec2 P1 = iuv + uv_dir * dither;
        vec2 ZWd = ZW + dZW * dither;

        if (P1.x < 0 || P1.y < 0 || P1.x > viewWidth || P1.y > viewHeight) return ivec2(0);

        float z = (ZWd.x + ZWd.x * 0.5) / (ZWd.y + ZWd.y * 0.5);

        if (-z > far * 0.9) break;

        float zmin = z_prev, zmax = z;
        if (z_prev > z) {
            zmin = z;
            zmax = z_prev;
        }

        z_prev = z;

        //float sampled_zmax = texelFetch(depthtex0, ivec2(P1), 0).r;
        float sampled_zmax = proj2view(getProjPos(ivec2(P1))).z;
        last_z = sampled_zmax;
        float sampled_zmin = sampled_zmax - zThickness;

        if (zmax > sampled_zmin && zmin < sampled_zmax) {
            hit = ivec2(P1);
            break;                
        }

        uv_dir *= 1.4;
        dZW *= 1.4;
    }

    if (checkNormals) {
        vec3 n = normalDecode(texelFetch(colortex4, hit, 0).r);
        if (dot(n, dir) > 0) {
            return ivec2(0);
        }
    }

    return hit;
}

#define PCSS

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite = texelFetch(colortex0, iuv, 0).rgb;

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    float subsurface = decoded_b.b;

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        float ao = 0.0;

        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        float skyLight = smoothstep(0.04, 1.0, lmcoord.y);
        vec3 L = vec3(0.0);

        //vec3 ray_trace_dir = reflect(normalize(view_pos), normal);
        const int num_sspt_rays = 4;
        const float weight_per_ray = 1.0 / float(num_sspt_rays);

        for (int i = 0; i < num_sspt_rays; i++) {
            float noise_sample = fract(bayer64(iuv));
            vec2 grid_sample = WeylNth(int(noise_sample * (4096 * num_sspt_rays) + (frameCounter & 0xFF) * (4096 * num_sspt_rays) + i));
            grid_sample.x *= 0.8;
            vec3 object_space_sample = get_uniform_hemisphere_weighted(grid_sample);
            vec3 ray_trace_dir = make_coord_space(normal) * object_space_sample;
            //vec3 ray_trace_dir = reflect(normalize(view_pos), normal);

            ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, false);
            if (reflected != ivec2(0)) {
                vec3 radiance = texelFetch(colortex0, reflected, 0).rgb;

                vec3 sampled_vpos = proj2view(getProjPos(ivec2(reflected)));
                vec3 sampled_normal = normalDecode(texelFetch(colortex4, reflected, 0).r);
                vec3 offset = vec3(sampled_vpos - view_pos);
                radiance *= step(0.0, dot(sampled_normal, -ray_trace_dir)) / ((1.0 + dot(offset, offset)) * object_space_sample.z);
                L += radiance * 3.1415926;
            } else {
                ao += 1.0;
            }
        }
        
        ao = ao * weight_per_ray;
        L *= weight_per_ray;

        L += skyColor * ao * ambientIntensity * min(skyLight, ao); // 15000 lux
        
        composite += color.rgb * L;

        //composite = L;
        //composite = vec3(ao);
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(composite, 1.0);
    gl_FragData[1] = vec4(composite, 1.0);
}