#ifndef _INCLUDE_TRANSFORM
#define _INCLUDE_TRANSFORM

#define TRANSFORMATIONS_INVERSE
#define TRANSFORMATIONS
#define VECTORS
#define BUFFERS

#include "uniforms.glsl"

float norm2(in vec3 a, in vec3 b) {
    a -= b;
    return dot(a, a);
}

float square(float a) {
    return a * a;
}

#ifdef USE_HALF
float16_t square16(float16_t a) {
    return a * a;
}
#endif

float fsqrt(float x) {
    // [Drobot2014a] Low Level Optimizations for GCN
    return intBitsToFloat(0x1FBD1DF5 + (floatBitsToInt(x) >> 1));
}

float facos(float x) {
    // [Eberly2014] GPGPU Programming for Games and Science
    float res = -0.156583 * abs(x) + 3.1415926 / 2.0;
    res *= fsqrt(1.0 - abs(x));
    return x >= 0 ? res : 3.1415926 - res;
}


#define PI 3.1415926f

vec3 project_uv2skybox(vec2 uv) {
    vec2 rad = uv * 8.0 * PI;
    rad.y -= PI * 0.5;
    float cos_y = cos(rad.y);
    return vec3(cos(rad.x) * cos_y, sin(rad.y), sin(rad.x) * cos_y);
}

vec2 project_skybox2uv(vec3 nwpos) {
    vec2 rad = vec2(atan(nwpos.z, nwpos.x), asin(nwpos.y));
    rad += vec2(step(0.0, -rad.x) * (PI * 2.0), PI * 0.5);
    rad *= 0.125 / PI;
    return rad;
}

float getDepth(in ivec2 iuv) {
    return texelFetch(depthtex0, iuv, 0).r;
}

float linearizeDepth(in float d) {
    return (2 * near) / (far + near - (d * 2.0 - 1.0) * (far - near));
}

vec4 linearizeDepth(in vec4 d) {
    return (2 * near) / (far + near - (d * 2.0 - 1.0) * (far - near));
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

vec3 view2proj(in vec3 view_pos) {
    vec4 proj_pos = gbufferProjection * vec4(view_pos, 1.0);
    return proj_pos.xyz / proj_pos.w;
}

vec3 view2world(in vec3 view_pos) {
    return (gbufferModelViewInverse * vec4(view_pos.xyz, 1.0)).xyz;
}

vec3 world2view(in vec3 wpos) {
    return (gbufferModelView * vec4(wpos, 1.0)).xyz;
}

vec3 world2shadowView(in vec3 world_pos) {
    return (shadowModelView * vec4(world_pos, 1.0)).xyz;
}

vec3 shadowProjCascaded(in vec3 spos, out float scale, out float dscale) {
    float largest_axis = max(abs(spos.x), abs(spos.y));

    if (largest_axis < 0.495) {
        // Top Left
        spos.xy *= 1.0;
        spos.z *= 0.5;
        scale = 1.0;
        dscale = 2.0;
        spos.xy += vec2(-0.5, 0.5);
    } else if (largest_axis < 1.9) {
        // Top Right
        spos.xy *= 0.25;
        spos.z *= 0.5;
        scale = 0.25;
        dscale = 2.0;
        spos.xy += vec2(0.5, 0.5);
    } else if (largest_axis < 3.8) {
        // Bottom Left
        spos.xy *= 0.125;
        spos.z *= 0.25;
        scale = 0.5;
        dscale = 4.0;
        spos.xy += vec2(-0.5, -0.5);
    } else if (largest_axis < 16) {
        // Bottom Right
        spos.xy *= 0.03125;
        spos.z *= 0.0625;
        scale = 0.25;
        dscale = 16.0;
        spos.xy += vec2(0.5, -0.5);
    } else {
        spos = vec3(-1);
    }

    return spos * 0.5 + 0.5;
}

mat4 shadowMVP = shadowProjection * shadowModelView;

vec3 world2shadowProj(in vec3 world_pos) {
    vec4 shadow_proj_pos = vec4(world_pos, 1.0);
    shadow_proj_pos = shadowMVP * shadow_proj_pos;
    shadow_proj_pos.xyz /= shadow_proj_pos.w;
    vec3 spos = shadow_proj_pos.xyz;

    return spos;
}

float sposLinear(in vec3 spos) {
    float largest_axis = max(abs(spos.x), abs(spos.y));

    if (largest_axis < 0.495) {
        // Top Left
        return spos.z * 2.0;
    } else if (largest_axis < 1.9) {
        // Top Right
        return spos.z * 2.0;
    } else if (largest_axis < 3.8) {
        // Bottom Left
        return spos.z * 4.0;
    } else if (largest_axis < 16) {
        // Bottom Right
        return spos.z * 16.0;
    } else {
        return 1.0;
    }
}

#endif