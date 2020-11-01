#version 420 compatibility
#pragma optimize(on)

/* DRAWBUFFERS:5 */

#include "/libs/compat.glsl"

const bool colortex3Clear = false;

#define VECTORS
#define BUFFERS

#include "/libs/uniforms.glsl"
#include "/libs/encoding.glsl"
#include "/libs/sampling.glsl"
#include "/libs/transform.glsl"
#include "/libs/bsdf.glsl"
#include "/libs/color.glsl"
#include "/libs/noise.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float depth = getDepth(iuv);

    vec3 composite = texelFetch(colortex3, iuv / 2, 0).rgb;

    if (depth < 1.0) {
        vec3 min_bound = vec3(100.0);
        vec3 max_bound = vec3(0.0);

        vec3 s;
        
        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2(-1, -1)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2( 0, -1)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2( 1, -1)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2(-1,  0)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2( 1,  0)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2(-1,  1)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);
    
        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2( 0,  1)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        s = texelFetchOffset(colortex3, iuv / 2, 0, ivec2( 1,  1)).rgb;
        min_bound = min(min_bound, s);
        max_bound = max(max_bound, s);

        composite = clamp(composite, min_bound, max_bound);
    }

    gl_FragData[0] = vec4(composite, 1.0);
}