#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec2 uv;

uniform int frameCounter;

#ifdef VERTEX

#include "taa.glsl"
uniform vec2 invWidthHeight;

out float fragDepth;

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    gl_Position = mvp_mat * input_pos;

    gl_Position.st += JitterSampleOffset(frameCounter / 10) * invWidthHeight * gl_Position.w;
}

#else

uniform sampler2D tex;

uniform vec4 projParams;

uniform int fogMode;

uniform vec3 fogColor;

void fragment() {
/* DRAWBUFFERS:0 */
    vec4 c = fromGamma(color * texture(tex, uv));

    c.rgb = c.ggg * fromGamma(fogColor) * c.a;

    gl_FragData[0] = c;
}

#endif