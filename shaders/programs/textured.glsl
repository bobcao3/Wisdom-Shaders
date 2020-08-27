#include "/libs/compat.glsl"
#include "/libs/encoding.glsl"

#include "/libs/color.glsl"

#define NORMAL_MAPPING

INOUT vec4 color;
INOUT flat vec3 normal;
INOUT flat float subsurface;
INOUT flat float blockId;

#ifdef NORMAL_MAPPING
INOUT flat vec3 tangent;
INOUT flat vec3 bitangent;
#endif

INOUT vec3 worldPos;
INOUT vec3 viewPos;
INOUT vec2 uv;
INOUT vec2 lmcoord;

uniform vec3 cameraPosition;

uniform int frameCounter;

#ifdef VERTEX

#include "/libs/taa.glsl"
uniform vec2 invWidthHeight;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

#ifdef ENTITY
uniform vec4 entityColor;
#endif

uniform mat4 gbufferModelViewInverse;

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
#ifdef ENTITY
    color += entityColor;
#endif
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    normal = normalize(gl_NormalMatrix * gl_Normal);

#ifdef NORMAL_MAPPING
    tangent = normalize(gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
    bitangent = cross(tangent, normal);
#endif

    subsurface = 0.0;

    blockId = mc_Entity.x;
    if (blockId == 31.0) {
        subsurface = 0.3;        
    } else if (blockId == 18.0) {
        subsurface = 0.5;
    } else if (blockId == 79.0) {
        subsurface = 1.0;
    } else if (blockId == 8001.0) {
        subsurface = 0.5;
    }

    vec4 vpos = model_view_mat * input_pos;
    viewPos = vpos.xyz;
    worldPos = (gbufferModelViewInverse * vpos).xyz;

    gl_Position = proj_mat * vpos;

#ifndef NO_TAA
    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
#endif
}

#else

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D gaux3;

uniform vec4 projParams;

uniform float wetness;

#include "/libs/noise.glsl"

#define RAIN_PUDDLES

// float getDirectional(float lm, vec3 normal2) {
// 	float Lx = dFdx(lm) * 60.0;
// 	float Ly = dFdy(lm) * 60.0;
//
// 	vec3 TL = normalize(vec3(Lx * tangent + 0.005 * normal + Ly * bitangent));
// 	float dir_lighting = fma((dot(normal2, TL)), 0.33, 0.67);
//	
// 	return clamp(dir_lighting * 1.4, 0.0, 1.0);
// }

void fragment() {
/* DRAWBUFFERS:4 */
    float threshold = fract(texelFetch(gaux3, ivec2(gl_FragCoord.st) % 0xFF, 0).r + texelFetch(gaux3, ivec2(frameCounter) % 0xFF, 0).r) * 0.95 + 0.05;

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    float dL = min(length(ddx), length(ddy.x));
    float lod = clamp(round(log2(dL * textureSize(tex, 0).x) - 1.0), 0, 3);

    vec2 lmcoord_dithered = lmcoord + bayer8(gl_FragCoord.st) * 0.004;

#if (defined(ENTITY) || !defined(NORMAL_MAPPING))
    vec3 normal_map = normal;
#else
    vec3 normal_map = texture(normals, uv, lod).rgb * 2.0 - 1.0;
    normal_map = mat3(tangent, bitangent, normal) * normal_map;
#endif

    //lmcoord_dithered.x *= getDirectional(lmcoord.x, normal_map);

    vec4 specular_map = texture(specular, uv, lod);

    if (blockId > 8001.5 && blockId < 8002.5) {
        specular_map.a = 0.95;
    }

    #ifdef UNLIT
    lmcoord_dithered = vec2(0.7);
    specular_map.a = 0.95;
    #endif

    vec4 c = color * textureLod(tex, uv, lod);

    c.rgb += vec3(threshold - 0.5) / vec3(32.0, 64.0, 32.0);
    c.rgb = max(c.rgb, vec3(0.0));

#if (!defined(ENTITY) && defined(RAIN_PUDDLES))
    float wetnessMorph = 0.5 * noise(worldPos.xz + cameraPosition.xz);
    wetnessMorph += 1.5 * noise(worldPos.xz * 0.5 + cameraPosition.xz * 0.5);
    wetnessMorph += 2.0 * noise(worldPos.xz * 0.2 + cameraPosition.xz * 0.2);
    wetnessMorph = clamp(wetnessMorph + 1.0, 0.0, 1.0) * wetness * smoothstep(0.9, 0.95, lmcoord.y);

    if (threshold < wetnessMorph * pow(1.0 - abs(dot(normalize(viewPos), normal)), 3.0))
    {
        specular_map.rg = vec2(0.99, 1.0);
        normal_map = normal;
    }

#ifdef RAIN_PUDDLES
    if (specular_map.b < 0.25) c.rgb *= 1.0 - specular_map.b * 2.0;
#endif
#endif

    if (c.a < threshold) discard;
    fragData[0] = uvec3(normalEncode(normal_map), encodeAlbedoSpecular(c.rgb, specular_map.rg), packUnorm4x8(vec4(lmcoord_dithered, subsurface / 16.0, specular_map.a)));
}

#endif