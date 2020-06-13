#version 420 compatibility
#pragma optimize(on)

const bool colortex1Clear = false;
const bool colortex3Clear = false;

#define VECTORS
#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/transform.glsl"
#include "libs/bsdf.glsl"
#include "libs/color.glsl"
#include "libs/noise.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite = texelFetch(colortex0, iuv, 0).rgb;
    vec4 Ld = texelFetch(colortex3, iuv, 0);
    vec4 Ls = texelFetch(colortex1, iuv, 0);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;

    if (proj_pos.z < 0.9999) {
        composite += color.rgb * Ld.rgb + Ls.rgb;
        // composite = Ld.rgb;
        // composite = Ls.rgb;
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(composite, 1.0);
    gl_FragData[1] = vec4(composite, 1.0);
}