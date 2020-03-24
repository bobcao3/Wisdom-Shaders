#define TRANSFORMATIONS_INVERSE
#define TRANSFORMATIONS
#define VECTORS
#define BUFFERS

#include "uniforms.glsl"

float getDepth(in ivec2 iuv) {
    return texelFetch(depthtex0, iuv, 0).r;
}

float linearizeDepth(in float d) {
    return (2 * projParams.x) / (projParams.y + projParams.x - (d * 2.0 - 1.0) * (projParams.y - projParams.x));
}

vec4 linearizeDepth(in vec4 d) {
    return (2 * projParams.x) / (projParams.y + projParams.x - (d * 2.0 - 1.0) * (projParams.y - projParams.x));
}

vec3 getProjPos(in ivec2 iuv) {
    return vec3(vec2(iuv) * invWidthHeight, getDepth(iuv)) * 2.0 - 1.0;
}

vec3 getProjPos(in ivec2 iuv, in float depth) {
    return vec3(vec2(iuv) * invWidthHeight, depth) * 2.0 - 1.0;
}

vec3 getProjPos(in vec2 uv, in float depth) {
    return vec3(uv, depth) * 2.0 - 1.0;
}

vec3 proj2view(in vec3 proj_pos) {
    vec4 view_pos = gbufferProjectionInverse * vec4(proj_pos, 1.0);
    return view_pos.xyz / view_pos.w;
}

vec3 view2world(in vec3 view_pos) {
    return (gbufferModelViewInverse * vec4(view_pos.xyz, 1.0)).xyz;
}

vec3 world2shadowView(in vec3 world_pos) {
    return (shadowModelView * vec4(world_pos, 1.0)).xyz;
}

vec3 world2shadowProj(in vec3 world_pos, out float bias) {
    vec4 shadow_proj_pos = vec4(world2shadowView(world_pos), 1.0);
    shadow_proj_pos = shadowProjection * shadow_proj_pos;
    shadow_proj_pos.xyz /= shadow_proj_pos.w;
    vec3 spos = shadow_proj_pos.xyz;

    float largest_axis = max(abs(spos.x), abs(spos.y));

    if (largest_axis < 0.495) {
        // Top Left
        spos.xy *= 1.0;
        spos.z *= 0.5;
        spos.xy += vec2(-0.5, 0.5);
        bias = 0.00005;
    } else if (largest_axis < 1.9) {
        // Top Right
        spos.xy *= 0.25;
        spos.z *= 0.5;
        spos.xy += vec2(0.5, 0.5);
        bias = 0.0001;
    } else if (largest_axis < 3.8) {
        // Bottom Left
        spos.xy *= 0.125;
        spos.z *= 0.5;
        spos.xy += vec2(-0.5, -0.5);
        bias = 0.0005;
    } else if (largest_axis < 16) {
        // Bottom Right
        spos.xy *= 0.03125;
        spos.z *= 0.25;
        spos.xy += vec2(0.5, -0.5);
        bias = 0.001;
    } else {
        spos = vec3(-1);
    }

    return spos * 0.5 + 0.5;
}