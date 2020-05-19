#ifndef _INCLUDE_SAMPLING
#define _INCLUDE_SAMPLING

#include "./../configs.glsl"

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

float shadowTexSmooth(in sampler2D tex, in vec3 spos, out float depth, in float bias) {
    const vec2 resolution = vec2(shadowMapResolution);
    const vec2 invresolution = 1.0 / resolution;

    vec2 f = fract(spos.xy * resolution);

    vec4 dsamples = textureGather(tex, spos.xy + invresolution * 0.5);
    vec4 samples = step(spos.z, dsamples + bias);

    depth = dot(dsamples, vec4(0.25));
    
    return mix(mix(samples.w, samples.z, f.x), mix(samples.x, samples.y, f.x), f.y);
}

#include "./noise.glsl"

float getShadowRadiusPCSS(in sampler2D tex, in vec3 spos, out float depth, in float scale) {
    const vec2 resolution = vec2(shadowMapResolution);
    const vec2 invresolution = 1.0 / resolution;

    float shadow = 0.0;
    depth = 1.0;

    for (int i = 0; i < 12; i++) {
        vec4 dsample = textureGather(tex, spos.xy + invresolution * 0.5 + vec2(poisson_12[i] * 0.05));
        depth = min(depth, min(min(dsample.x, dsample.y), min(dsample.z, dsample.w)));
    }

    const float sunSize = 0.2;

    return max(spos.z - depth, 0.0005) * sunSize * scale;
}

float shadowFiltered(in sampler2D tex, in vec3 spos, out float depth, in float bias, in float radius) {
    const vec2 resolution = vec2(shadowMapResolution);
    const vec2 invresolution = 1.0 / resolution;

    float shadow = 0.0;
    depth = 0.0;

    for (int i = 0; i < 12; i++) {
        float d;
        shadow += shadowTexSmooth(tex, spos + vec3(poisson_12[i] * radius, 0.0), d, bias);
        depth += d;
    }

    const float inv12 = 1.0 / 12.0;

    depth *= inv12;

    return shadow * inv12;
}

#endif