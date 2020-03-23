#include "compat.glsl"
#include "encoding.glsl"

INOUT vec4 color;
INOUT vec3 normal;

#ifdef VERTEX

void vertex() {
    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
}

#else

#include "color.glsl"

void fragment() {
/* DRAWBUFFERS:4 */
    fragData[0] = uvec4(encode_depth_normal(normal, gl_FragCoord.z), packUnorm4x8(fromGamma(color)), packUnorm4x8(vec4(0.0)), 0);
}

#endif