#version 420 compatibility
#pragma optimize(on)

#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"

#define VECTORS
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

#define PCSS

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal;
    float _depth;
    decode_depth_normal(gbuffers.r, normal, _depth);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    float subsurface = decoded_b.b;

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        //int cascade = int(clamp(floor(log2(max(abs(world_pos.x), abs(world_pos.z)) / 8.0)), 0.0, 4.0));
        float bias, scale;
        vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * 0.05, bias, scale);

        float shadow_sampled_depth;
#ifdef PCSS
        float shadow_radius = getShadowRadiusPCSS(shadowtex1, shadow_proj_pos, shadow_sampled_depth, scale);
#else
        const float shadow_radius = 0.0005;
#endif
        float shadow = shadowFiltered(shadowtex1, shadow_proj_pos, shadow_sampled_depth, bias, shadow_radius);
        vec3 sun_vec = normalize(shadowLightPosition);

        vec3 spos_diff = vec3(shadow_proj_pos.xy, max(shadow_proj_pos.z - shadow_sampled_depth, 0.0));
        float subsurface_depth = 1.0 - smoothstep(sposLinear(spos_diff) * 256.0, 0.0, subsurface * 0.5 + pow(abs(dot(normalize(view_pos), sun_vec)), 8.0));

        float ao = blurAO(iuv, uv, depth);
        vec3 bounce_ao = GTAOMultiBounce(ao, color.rgb);

        if (subsurface > 0.0) {
            shadow = min(subsurface_depth, 1.0) * ao;
        } else {
            shadow = max(0.0, dot(normal, sun_vec)) * shadow;
        }

        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float sunIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01) * (1.0 - rainStrength * 0.9);
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        vec3 sun_I = vec3(9.8) * sunIntensity; // 98000 lux
        vec3 L = sun_I * shadow;

        float skyLight = lmcoord.y;
        L += 1.5 * bounce_ao * ambientIntensity * skyLight; // 15000 lux

        float blockLight = pow(lmcoord.x, 4.0);
        L += vec3(1.0, 0.8, 0.6) * 1.0 * blockLight; // 10000 lux

        color.rgb = diffuse_bsdf(color.rgb) * L;

        //color.rgb = bounce_ao;
    } else {
        color.rgb = fromGamma(texelFetch(colortex0, iuv, 0).rgb) * 3.0;
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = color;
    gl_FragData[1] = color;
}