#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;

#ifdef VERTEX

void vertex() {
    color = gl_Color;
    color.rgb = fromGamma(color.rgb);
}

#else

uniform sampler2D tex;

uniform vec4 projParams;

void fragment() {
/* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}

#endif