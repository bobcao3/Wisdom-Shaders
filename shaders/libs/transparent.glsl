#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec4 viewPos;
INOUT vec2 uv;
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

    viewPos = model_view_mat * input_pos;
    gl_Position = proj_mat * viewPos;

    gl_FogFragCoord = length(viewPos.xyz);

    layer = mc_Entity.x;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#else

uniform sampler2D tex;

uniform vec4 projParams;

uniform int fogMode;

#define VECTORS
#define BUFFERS
#include "uniforms.glsl"

#include "noise.glsl"

void fragment() {
/* DRAWBUFFERS:0 */
    vec4 c = color * texture(tex, uv);
    c.rgb = fromGamma(c.rgb);

    ivec2 iuv = ivec2(gl_FragCoord.st);

    float fresnel = pow(1.0 - max(dot(normal, -normalize(viewPos.xyz)), 0.0), 2.0);
    c.rgb = c.rgb * texelFetch(gaux2, iuv, 0).rgb + c.rgb * fresnel * skyColor;

    c.a = clamp(0.7 + fresnel * 0.3, 0.0, 1.0);

    gl_FragData[0] = c;

    if(fogMode == 9729)
        gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp((gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0));
    else if(fogMode == 2048)
        gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0));
}

#endif