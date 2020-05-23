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

#define PCSS

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    float subsurface = decoded_b.b;

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        //int cascade = int(clamp(floor(log2(max(abs(world_pos.x), abs(world_pos.z)) / 8.0)), 0.0, 4.0));
        float scale;
        vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * 0.05);

        float shadow_sampled_depth;
#ifdef PCSS
        float shadow_radius = getShadowRadiusPCSS(shadowtex1, shadow_proj_pos, shadow_sampled_depth, iuv);
#else
        const float shadow_radius = 0.001;
#endif
        float shadow = shadowFiltered(shadowtex1, shadow_proj_pos, shadow_sampled_depth, shadow_radius, iuv);
        //shadow = min(1.0, contactShadow(view_pos, vec2(iuv), normal));
        vec3 sun_vec = normalize(shadowLightPosition);

        vec3 spos_diff = vec3(shadow_proj_pos.xy, max(shadow_proj_pos.z - shadow_sampled_depth, 0.0));
        float subsurface_depth = 1.0 - smoothstep(sposLinear(spos_diff) * 128.0, 0.0, subsurface * 0.5 + pow(abs(dot(normalize(view_pos), sun_vec)), 8.0));

        if (subsurface > 0.0) {
            shadow = min(subsurface_depth, 1.0);
        } else {
            shadow = max(0.0, dot(normal, sun_vec)) * shadow;
        }

        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float sunIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01) * (1.0 - rainStrength * 0.9);
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        vec3 sun_I = vec3(9.8) * sunIntensity; // 98000 lux
        vec3 L = sun_I * shadow;

        float blockLight = pow(lmcoord.x, 4.0);
        L += vec3(1.0, 0.8, 0.6) * 1.0 * blockLight; // 10000 lux

        color.rgb = diffuse_bsdf(color.rgb) * L;
    } else {
        color.rgb = fromGamma(texelFetch(colortex0, iuv, 0).rgb) * 3.0;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}