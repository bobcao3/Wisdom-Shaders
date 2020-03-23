#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;
uniform usampler2D colortex4;
uniform sampler2D shadowtex1;
uniform sampler2D depthtex0;

uniform vec2 invWidthHeight;

#define TRANSFORMATIONS_INVERSE
#define TRANSFORMATIONS
#define VECTORS

#include "libs/uniforms.glsl"
#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"

float getDepth(in ivec2 iuv) {
    return texelFetch(depthtex0, iuv, 0).r;
}

vec3 getProjPos(in ivec2 iuv) {
    return vec3(vec2(iuv) * invWidthHeight, getDepth(iuv)) * 2.0 - 1.0;
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

float rand(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5f, a.y * .75f)) );
}

#define bayer4(a)   (bayer2( .5f*(a))*.25f+bayer2(a))
#define bayer8(a)   (bayer4( .5f*(a))*.25f+bayer2(a))
#define bayer16(a)  (bayer8( .5f*(a))*.25f+bayer2(a))
#define bayer32(a)  (bayer16(.5f*(a))*.25f+bayer2(a))
#define bayer64(a)  (bayer32(.5f*(a))*.25f+bayer2(a))

uniform float viewHeight;
uniform float viewWidth;

float getHorizonAngle(ivec2 iuv, vec2 offset, vec3 vpos, vec3 vnorm) {
    ivec2 suv = iuv + ivec2(offset * vec2(viewHeight, viewHeight));

    if (suv.x < 0 || suv.y < 0 || suv.x > viewWidth || suv.y > viewHeight) return -1.0;

    vec3 proj_pos = getProjPos(suv);
    vec3 view_pos = proj2view(proj_pos);
    
    vec3 ws = view_pos - vpos;
    ws = normalize(ws);

    return dot(vnorm, ws);
}

float getAO(ivec2 iuv, vec2 uv, vec3 vpos, vec3 vnorm) {
    float rand1 = bayer4(iuv);
    float rand2 = rand(uv);
    float angle = rand1 * 3.1415926;
    float radius = 1.0 / -vpos.z;

    radius = clamp(radius, 0.01, 0.3);

    float ao = 0.0;

    for (int n = 0; n < 4; n++) {
        angle += 3.1415926 / 4.0;

        vec2 t = vec2(cos(angle), sin(angle));

        float theta1 = -1.0, theta2 = -1.0;

        for (int i = 0; i < 2; i++) {
            float r = radius * (float(i) + rand2 + 0.5) * 0.5;
            float h1 = getHorizonAngle(iuv, t * r, vpos, vnorm);
            theta1 = max(theta1, h1);
            float h2 = getHorizonAngle(iuv, -t * r, vpos, vnorm);
            theta2 = max(theta2, h2);
        }

        theta1 = -acos(theta1);
        theta2 = acos(theta2);

        vec3 wo_norm = -normalize(vpos);
        
        vec3 bitangent	= normalize(cross(vec3(t, 0.0), wo_norm));
        vec3 tangent	= cross(wo_norm, bitangent);
        vec3 nx			= vnorm - bitangent * dot(vnorm, bitangent);

        float nnx		= length(nx);
        float invnnx	= 1.0 / (nnx + 1e-6);			// to avoid division with zero
        float cosxi		= dot(nx, tangent) * invnnx;	// xi = gamma + HALF_PI
        float gamma		= acos(cosxi) - 3.1415926 / 2.0;
        float cos_gamma	= dot(nx, wo_norm) * invnnx;
        float sin_gamma = -2.0 * cosxi;

        theta1 = gamma + max(theta1 - gamma, -3.1415926 / 2.0);
        theta2 = gamma + min(theta2 - gamma,  3.1415926 / 2.0);

        float alpha = 0.5 * cos_gamma + 0.25 * (theta1 + theta2) * sin_gamma - 0.25 * (cos(2.0 * theta1 - gamma) + cos(2.0 * theta2 - gamma));

        ao += nnx * alpha / 4.0;
    }

    return ao;
}

uniform vec4 projParams;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 proj_pos = getProjPos(iuv);

    vec4 color = unpackUnorm4x8(texelFetch(colortex4, iuv, 0).g);
    vec3 normal;
    float depth;
    decode_depth_normal(texelFetch(colortex4, iuv, 0).r, normal, depth);

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        //int cascade = int(clamp(floor(log2(max(abs(world_pos.x), abs(world_pos.z)) / 8.0)), 0.0, 4.0));
        float bias;
        vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * 0.05, bias);

        float shadow_sampled_depth;
        float shadow = shadowTexSmooth(shadowtex1, shadow_proj_pos, shadow_sampled_depth, bias);

        vec3 sun_vec = normalize(shadowLightPosition);
        vec3 sun_I = vec3(9.8); // 98000 lux
        vec3 L = sun_I * (max(0.0, dot(normal, sun_vec)) * shadow);

        float ao = 2 * getAO(iuv, vec2(iuv) / vec2(viewWidth, viewHeight), view_pos, normal);
        L += 2 * ao; // 20000 lux

        color.rgb = diffuse_bsdf(color.rgb) * L;

        //color.rgb = vec3(ao);
    } else {
        color.rgb = texelFetch(colortex0, iuv, 0).rgb;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}