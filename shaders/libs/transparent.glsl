#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec4 viewPos;
INOUT vec2 uv;
INOUT vec2 lmcoord;
INOUT float layer;

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
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    viewPos = model_view_mat * input_pos;
    gl_Position = proj_mat * viewPos;

    gl_FogFragCoord = length(viewPos.xyz);

    layer = mc_Entity.x;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#else

uniform sampler2D tex;

#define VECTORS
#define BUFFERS
#include "uniforms.glsl"
#include "transform.glsl"

#include "noise.glsl"

void fragment() {
/* DRAWBUFFERS:0 */
    vec4 c = color * texture(tex, uv);
    c.rgb = fromGamma(c.rgb);

    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 nvpos = normalize(viewPos.xyz);
    float fresnel = pow(1.0 - max(dot(normal, -nvpos), 0.0), 2.0);
    
    vec3 reflect_dir = reflect(nvpos, normal);
    vec3 dir = mat3(gbufferModelViewInverse) * reflect_dir;
    vec3 sky = texture(gaux4, project_skybox2uv(dir)).rgb;
    c.rgb = c.rgb * texelFetch(gaux2, iuv, 0).rgb + c.rgb * fresnel * sky * lmcoord.y;

    c.a = clamp(0.7 + fresnel * 0.3, 0.0, 1.0);

    gl_FragData[0] = c;
}

#endif