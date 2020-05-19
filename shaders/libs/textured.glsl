#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec2 uv;
INOUT vec2 lmcoord;
INOUT float subsurface;

uniform int frameCounter;

#ifdef VERTEX

#include "taa.glsl"
uniform vec2 invWidthHeight;

attribute vec4 mc_Entity;

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
    color.rgb = fromGamma(color.rgb);
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    subsurface = 0.0;

    float blockId = mc_Entity.x;
    if (blockId == 31.0 || blockId == 18.0) {
        subsurface = 0.5;
    } else if (blockId == 79.0) {
        subsurface = 1.0;
    } else if (blockId == 8001.0) {
        subsurface = 0.5;
    }

    gl_Position = mvp_mat * input_pos;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#else

uniform sampler2D tex;

uniform vec4 projParams;

#include "noise.glsl"

void fragment() {
/* DRAWBUFFERS:4 */
    float threshold = bayer8(vec2(gl_FragCoord.st) + frameCounter) * 0.95 + 0.05;

    vec4 c = color * fromGamma(textureLod(tex, uv, 0));
    if (c.a < threshold) discard;
    fragData[0] = uvec4(encode_depth_normal(normal, gl_FragCoord.z), packUnorm4x8(c), packUnorm4x8(vec4(lmcoord, subsurface, 0.0)), 0);
}

#endif