#ifndef _INCLUDE_SAMPLING
#define _INCLUDE_SAMPLING

#include "/configs.glsl"
#include "/libs/transform.glsl"

// Bicubic sampling from Robobo1221
vec4 Cubic(float x) {
    float x2 = x * x;
    float x3 = x2 * x;

    vec4 w   = vec4(0.0);
         w.x =       -x3 + 3.0 * x2 - 3.0 * x + 1.0;
         w.y =  3.0 * x3 - 6.0 * x2           + 4.0;
         w.z = -3.0 * x3 + 3.0 * x2 + 3.0 * x + 1.0;
         w.w = x3;

    return w * 0.166666666667;
}

vec4 bicubicSample(sampler2D tex, vec2 coord) {
    vec2 resolution = vec2(textureSize(tex, 0));

    coord *= resolution;

    vec2 f = fract(coord);

    resolution = 1.0 / resolution;

    coord -= f;

    vec4 xCubic = Cubic(f.x);
    vec4 yCubic = Cubic(f.y);

    vec4 s = vec4(xCubic.xz + xCubic.yw, yCubic.xz + yCubic.yw);
    vec4 offset = coord.xxyy + vec4(-.5, 1.5, -.5, 1.5) + vec4(xCubic.yw, yCubic.yw) / s;

    vec4 sample0 = texture(tex, offset.xz * resolution);
    vec4 sample1 = texture(tex, offset.yz * resolution);
    vec4 sample2 = texture(tex, offset.xw * resolution);
    vec4 sample3 = texture(tex, offset.yw * resolution);

    float sx = s.x / (s.x + s.y);
    float sy = s.z / (s.z + s.w);

    return mix(mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

float shadowTexSmooth(in sampler2D tex, in vec3 spos, out float depth, float bias) {
    const vec2 resolution = vec2(shadowMapResolution);
    const vec2 invresolution = 1.0 / resolution;

    if (spos.x < 0.0 || spos.x > 1.0 || spos.y < 0.0 || spos.y > 1.0 || spos.z < 0.0 || spos.z > 1.0) return 1.0;

    vec2 f = fract(spos.xy * resolution);

    vec4 dsamples = textureGather(tex, spos.xy + invresolution * 0.5);
    vec4 samples = step(spos.z, dsamples + bias);

    depth = dot(dsamples, vec4(0.25));
    
    return mix(mix(samples.w, samples.z, f.x), mix(samples.x, samples.y, f.x), f.y);
}

#include "/libs/noise.glsl"

#include "/libs/taa.glsl"
uniform int frameCounter;

float getShadowRadiusPCSS(in sampler2D tex, in vec3 spos, out float depth, in ivec2 iuv, out bool skipShadow, out float shadowEstiamte) {
    const vec2 resolution = vec2(shadowMapResolution);
    const vec2 invresolution = 1.0 / resolution;

    float s, ds;
    depth = 100.0;

    float allSamples = 0.0;

    for (int i = 0; i < 4; i++) {
        vec2 grid_sample = fract(WeylNth(i - (frameCounter & 0x7) * 8) + bayer8(iuv));
        vec2 direction = vec2(cos(grid_sample.x * 3.1415926 * 2.0), sin(grid_sample.x * 3.1415926 * 2.0)) * grid_sample.y;

        vec3 spos_cascaded = shadowProjCascaded(spos + vec3(direction * 0.02, 0.0), s, ds);
        vec4 dsample = textureGather(tex, spos_cascaded.xy + invresolution * 0.5);
        depth = min(depth, (min(min(dsample.x, dsample.y), min(dsample.z, dsample.w)) * 2.0 - 1.0) * ds);

        allSamples += dot(step(spos_cascaded.z, dsample + 0.0001), vec4(1.0));
    }

    skipShadow = allSamples < 0.25 || allSamples > 15.75;
    shadowEstiamte = allSamples * 0.0625;

    const float sunSize = 1.5 / shadowDistance;

    return max((spos.z - depth) * sunSize, 2.0 / shadowMapResolution);
}

float shadowFiltered(in sampler2D tex, in vec3 spos, out float depth, in float radius, in ivec2 iuv) {
    const vec2 resolution = vec2(shadowMapResolution);
    const vec2 invresolution = 1.0 / resolution;

    float shadow = 0.0;
    depth = 0.0;

    for (int i = 0; i < 8; i++) {
        float d, s, ds;

        vec2 grid_sample = fract(WeylNth(i + (frameCounter & 0x7) * 8) + bayer8(iuv));
        vec2 direction = vec2(cos(grid_sample.x * 3.1415926 * 2.0), sin(grid_sample.x * 3.1415926 * 2.0)) * grid_sample.y;

        shadow += shadowTexSmooth(tex, shadowProjCascaded(spos + vec3(direction * radius, 0.0), s, ds), d, 0.0003);
        depth += (d * 2.0 - 1.0) * ds;
    }

    const float inv12 = 1.0 / 8.0;

    depth *= inv12;

    return shadow * inv12;
}

float sampleDepthLOD(ivec2 iuv, int lod) {
    if (lod == 0) {
        return texelFetch(depthtex1, iuv, 0).r;
    } else if (lod == 1) {
        return texelFetch(gaux3, iuv >> 1, 0).r;
    } else if (lod == 2) {
        return texelFetch(gaux3, (iuv >> 2) + ivec2(0, (int(viewHeight) >> 1)), 0).r;
    } else if (lod == 3) {
        return texelFetch(gaux3, (iuv >> 3) + ivec2(0, (int(viewHeight) >> 1) + (int(viewHeight) >> 2)), 0).r;
    }
    return 0.0;
}

float sampleDepthLODBilinear(vec2 uv, int lod) {
    if (lod == 0) {
        return texture(depthtex1, uv, 0).r;
    } else if (lod == 1) {
        return texture(gaux3, uv * 0.5, 0).r;
    } else if (lod == 2) {
        return texture(gaux3, uv * 0.25 + vec2(0, 0.5), 0).r;
    } else if (lod == 3) {
        return texture(gaux3, uv * 0.125 + vec2(0, 0.5 + 0.25), 0).r;
    }
    return 0.0;
}

#endif