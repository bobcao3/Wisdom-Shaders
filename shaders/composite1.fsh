#version 420 compatibility
#pragma optimize(on)

#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"
#include "configs.glsl"

#define VECTORS
#define CLIPPING_PLANE
#include "libs/uniforms.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    vec3 color = texelFetch(colortex0, iuv, 0).rgb;

/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}