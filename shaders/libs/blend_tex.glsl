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
/* DRAWBUFFERS:0 */
    vec4 c = color * texture(tex, uv);
    c.rgb = fromGamma(c.rgb);
    gl_FragData[0] = c;
}

#endif