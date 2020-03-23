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

    vec4 samples = step(spos.z, textureGather(tex, spos.xy + invresolution * 0.5) + bias);
    
    return mix(mix(samples.w, samples.z, f.x), mix(samples.x, samples.y, f.x), f.y);
}

#endif