#version 420 compatibility
#pragma optimize(on)

#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"

vec4 l1(in vec4 a, in vec4 b) {
    return abs(a - b);
}

float blurAO(ivec2 iuv, vec2 uv, float depth) {
    vec4 cdepth = vec4(linearizeDepth(depth));
    vec4 invdepth = vec4(1.0 / depth);

    vec4 dx = vec4(abs(dFdx(depth)) + abs(dFdy(depth)));

    const vec4 depth_threshold = vec4(0.01);

    // [-1, 0] [ 0, 0] [ 0,-1] [-1,-1]
    vec4 t0 = textureGatherOffset(colortex1, uv, ivec2(-2, -2), 1);
    vec4 d0 = textureGatherOffset(colortex1, uv, ivec2(-2, -2), 0);
    vec4 w0 = step(l1(d0, cdepth) * invdepth, depth_threshold);
    t0 = t0 * w0;

    // [ 1, 0] [ 2, 0] [ 2,-1] [ 1,-1]
    vec4 t1 = textureGatherOffset(colortex1, uv, ivec2( 0, -2), 1);
    vec4 d1 = textureGatherOffset(colortex1, uv, ivec2( 0, -2), 0);
    vec4 w1 = step(l1(d1, cdepth) * invdepth, depth_threshold);
    t1 = t1 * w1;

    // [-1, 2] [ 0, 2] [ 0, 1] [-1, 1]
    vec4 t2 = textureGatherOffset(colortex1, uv, ivec2(-2,  0), 1);
    vec4 d2 = textureGatherOffset(colortex1, uv, ivec2(-2,  0), 0);
    vec4 w2 = step(l1(d2, cdepth) * invdepth, depth_threshold);
    t2 = t2 * w2;

    // [ 1, 2] [ 2, 2] [ 2, 1] [ 1, 1]
    vec4 t3 = textureGatherOffset(colortex1, uv, ivec2( 0,  0), 1);
    vec4 d3 = textureGatherOffset(colortex1, uv, ivec2( 0,  0), 0);
    vec4 w3 = step(l1(d3, cdepth) * invdepth, depth_threshold);
    t3 = t3 * w3;

    float ao = dot((t0 + t2) + (t1 + t3), vec4(1.0)) / (dot((w0 + w2) + (w1 + w3), vec4(1.0)));

    //ao = dot((w0d1 + w1d1) + (w2d1 + w3d1), vec4(1.0));

    return clamp(ao, 0.0, 1.0);
}

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    vec4 color = unpackUnorm4x8(texelFetch(colortex4, iuv, 0).g);
    vec3 normal;
    float _depth;
    decode_depth_normal(texelFetch(colortex4, iuv, 0).r, normal, _depth);

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        //int cascade = int(clamp(floor(log2(max(abs(world_pos.x), abs(world_pos.z)) / 8.0)), 0.0, 4.0));
        float bias;
        vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * 0.05, bias);

        float shadow_sampled_depth;
        float shadow = shadowFiltered(shadowtex1, shadow_proj_pos, shadow_sampled_depth, bias, 0.0005);

        vec3 sun_vec = normalize(shadowLightPosition);
        vec3 sun_I = vec3(9.8); // 98000 lux
        vec3 L = sun_I * (max(0.0, dot(normal, sun_vec)) * shadow);

        float ao = blurAO(iuv, uv, depth);

        L += 2 * ao; // 20000 lux

        color.rgb = diffuse_bsdf(color.rgb) * L;

        //color.rgb = vec3(ao);
    } else {
        color.rgb = texelFetch(colortex0, iuv, 0).rgb;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}