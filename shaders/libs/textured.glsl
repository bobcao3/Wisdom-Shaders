#include "compat.glsl"
#include "encoding.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec2 uv;

#ifdef VERTEX

void vertex() {
    color = gl_Color;
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    normal = normalize(gl_NormalMatrix * gl_Normal);
}

#else

#include "color.glsl"

uniform sampler2D tex;

uniform vec4 projParams;

void fragment() {
/* DRAWBUFFERS:4 */
    vec4 c = color * texture(tex, uv);
    if (c.a < 0.2) discard;
    c = fromGamma(c);
    fragData[0] = uvec4(encode_depth_normal(normal, gl_FragCoord.z), packUnorm4x8(c), packUnorm4x8(vec4(0.0)), 0);
}

#endif