#version 420 compatibility
#pragma optimize(on)

#define VECTORS
#define BUFFERS

#include "libs/uniforms.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float depth_lod0 = texelFetch(depthtex0, iuv, 0).r;
    float depth_lod1 = texelFetch(depthtex0, (iuv << 1) + 1, 0).r;
    float depth_lod2 = texelFetch(depthtex0, (iuv << 2) + 2, 0).r;
    float depth_lod3 = texelFetch(depthtex0, (iuv << 3) + 4, 0).r;

/* DRAWBUFFERS:6 */
    gl_FragData[0] = vec4(depth_lod0, depth_lod1, depth_lod2, depth_lod3);
}