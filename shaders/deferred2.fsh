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

vec4 l1(in vec4 a, in vec4 b) {
    return abs(a - b);
}

vec4 normpdf(in vec4 x, in float sigma) {
	return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
}

float blurAO(ivec2 iuv, vec2 uv, float depth) {
    vec4 cdepth = vec4(linearizeDepth(depth));
    vec4 invdepth = vec4(1.0 / depth);

    const vec4 depth_threshold = vec4(0.1);

    vec4 center_ao = vec4(texelFetch(colortex1, iuv, 0).g);

    // [-1, 0] [ 0, 0] [ 0,-1] [-1,-1]
    vec4 t0 = textureGatherOffset(colortex1, uv, ivec2(-2, -2), 1);
    vec4 d0 = textureGatherOffset(colortex1, uv, ivec2(-2, -2), 0);
    vec4 w0 = normpdf(center_ao - t0, 0.2) * step(l1(d0, cdepth) * invdepth, depth_threshold) * vec4(0.023792, 0.094907, 0.059912, 0.015019);
    t0 = t0 * w0;

    // [ 1, 0] [ 2, 0] [ 2,-1] [ 1,-1]
    vec4 t1 = textureGatherOffset(colortex1, uv, ivec2( 0, -2), 1);
    vec4 d1 = textureGatherOffset(colortex1, uv, ivec2( 0, -2), 0);
    vec4 w1 = normpdf(center_ao - t1, 0.2) * step(l1(d1, cdepth) * invdepth, depth_threshold) * vec4(0.150342, 0.094907, 0.059912, 0.094907);
    t1 = t1 * w1;

    // [-1, 2] [ 0, 2] [ 0, 1] [-1, 1]
    vec4 t2 = textureGatherOffset(colortex1, uv, ivec2(-2,  0), 1);
    vec4 d2 = textureGatherOffset(colortex1, uv, ivec2(-2,  0), 0);
    vec4 w2 = normpdf(center_ao - t2, 0.2) * step(l1(d2, cdepth) * invdepth, depth_threshold) * vec4(0.003765, 0.015019, 0.059912, 0.015019);
    t2 = t2 * w2;

    // [ 1, 2] [ 2, 2] [ 2, 1] [ 1, 1]
    vec4 t3 = textureGatherOffset(colortex1, uv, ivec2( 0,  0), 1);
    vec4 d3 = textureGatherOffset(colortex1, uv, ivec2( 0,  0), 0);
    vec4 w3 = normpdf(center_ao - t3, 0.2) * step(l1(d3, cdepth) * invdepth, depth_threshold) * vec4(0.023792, 0.015019, 0.059912, 0.094907);
    t3 = t3 * w3;

    float ao = dot(t0 + t1 + t2 + t3, vec4(1.0)) / dot(w0 + w1 + w2 + w3, vec4(1.0));

    return clamp(ao, 0.0, 1.0);
}

uniform float rainStrength;

vec3 GTAOMultiBounce(float visibility, vec3 albedo) {
    vec3 a =  2.0404 * albedo - 0.3324;
    vec3 b = -4.7951 * albedo + 0.6417;
    vec3 c =  2.7552 * albedo + 0.6903;

    vec3 x = vec3(visibility);
    return max(x, ((x * a + b) * x + c) * x);
}

vec3 get_uniform_hemisphere_weighted(vec2 r) {
    float sin_theta = sin(acos(r.x));
    float phi = 2.0 * 3.1415926 * r.y;

    return vec3(cos(phi) * sin_theta, sin(phi) * sin_theta, r.x);
}

mat3 make_coord_space(vec3 n) {
    vec3 n_alter = n;
    if (n.y == 0) {
        n.y += 0.5;
    } else {
        n.x += 0.5; 
    }
    n_alter = normalize(n_alter);

    vec3 b = normalize(cross(n_alter, n));
    vec3 t = cross(n, b);

    return mat3(t, b, n);
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

    float stride = (viewHeight - viewHeight * min(0.96, -vpos.z * 0.001)) / 16.0;
    float dither = bayer64(iuv + (frameCounter & 0xF)) + 0.01;

    uv_dir *= stride;
    dZW *= invdx * stride;

    iuv += uv_dir * dither;
    ZW += dZW * dither;
    float z_prev = ZW.x / ZW.y;

    float zThickness = 16.0;//1.0 + (-vpos.z * 0.5);

    ivec2 hit = ivec2(0);

    float last_z = 0.0;

    for (int i = 0; i < 16; i++) {
        iuv += uv_dir;
        ZW += dZW;

        if (iuv.x < 0 || iuv.y < 0 || iuv.x > viewWidth || iuv.y > viewHeight) return ivec2(0);

        float z = (ZW.x + dZW.x * 0.5) / (ZW.y + dZW.y * 0.5);

        if (z > far) break;

        float zmin = z_prev, zmax = z;
        if (z_prev > z) {
            zmin = z;
            zmax = z_prev;
        }

        z_prev = z;

        //float sampled_zmax = texelFetch(depthtex0, ivec2(iuv), 0).r;
        float sampled_zmax = proj2view(getProjPos(ivec2(iuv))).z;
        last_z = sampled_zmax;
        float sampled_zmin = sampled_zmax - zThickness;

        if (zmax > sampled_zmin && zmin < sampled_zmax && abs(ZW.x / ZW.y - sampled_zmax) < zThickness) {
            hit = ivec2(iuv);
            break;                
        }
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

        float ao = 0.1;//blurAO(iuv, uv, depth) * 0.5;

        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        float skyLight = smoothstep(0.04, 1.0, lmcoord.y);
        vec3 L = vec3(0.0);

        //vec3 ray_trace_dir = reflect(normalize(view_pos), normal);
        vec2 grid_sample = WeylNth(int(bayer64(iuv) * 4096 + (frameCounter & 0xFF) * 4096));
        vec3 ray_trace_dir = make_coord_space(normal) * get_uniform_hemisphere_weighted(grid_sample);

        ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, false);
        if (reflected != ivec2(0)) {
            vec3 radiance = texelFetch(colortex0, reflected, 0).rgb;

            vec3 sampled_vpos = proj2view(getProjPos(ivec2(reflected)));
            vec3 sampled_normal = normalDecode(texelFetch(colortex4, reflected, 0).r);
            vec3 offset = vec3(sampled_vpos - view_pos);
            radiance *= max(0.0, dot(normal, ray_trace_dir)) / (1.0 + dot(offset, offset));
            L += radiance * 3.1415926;
        } else {
            ao += 0.9;
        }

        L += 1.5 * ao * ambientIntensity * skyLight; // 15000 lux
        
        composite += diffuse_bsdf(color.rgb) * L;

        composite = L;
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(composite, 1.0);
    gl_FragData[1] = vec4(composite, 1.0);
}