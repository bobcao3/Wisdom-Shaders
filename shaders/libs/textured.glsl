#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT float subsurface;
INOUT float blockId;
INOUT vec3 tangent;
INOUT vec3 bitangent;
INOUT vec2 uv;
INOUT vec2 lmcoord;

uniform int frameCounter;

#ifdef VERTEX

#include "taa.glsl"
uniform vec2 invWidthHeight;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

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
    tangent = normalize(gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
    bitangent = cross(tangent, normal);

    subsurface = 0.0;

    blockId = mc_Entity.x;
    if (blockId == 31.0) {
        subsurface = 0.1;        
    } else if (blockId == 18.0) {
        subsurface = 3.0;
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
uniform sampler2D normals;
uniform sampler2D specular;

uniform vec4 projParams;

#include "noise.glsl"

#ifdef ENTITY

#endif

void fragment() {
/* DRAWBUFFERS:4 */
    float threshold = bayer8(vec2(gl_FragCoord.st) + frameCounter) * 0.95 + 0.05;

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    float dL = min(length(ddx), length(ddy.x));
    int lod = clamp(int(round(log2(dL * textureSize(tex, 0).x))), 0, 3);

    vec2 lmcoord_dithered = lmcoord + bayer8(gl_FragCoord.st) * 0.004;

    vec3 normal_map = textureLod(normals, uv, lod).rgb * 2.0 - 1.0;
    normal_map = mat3(tangent, bitangent, normal) * normal_map;
    normal_map = normalize(mix(normal, normal_map, 0.5));

    vec4 specular_map = textureLod(specular, uv, lod);

    if (blockId > 8001.5 && blockId < 8002.5) {
        specular_map.a = 0.95;
    }

    vec4 c = color * fromGamma(textureLod(tex, uv, lod));
    if (c.a < threshold) discard;
    fragData[0] = uvec4(normalEncode(normal_map), packUnorm4x8(c), packUnorm4x8(vec4(lmcoord_dithered, subsurface / 16.0, specular_map.a)), packUnorm4x8(specular_map));
}

#endif