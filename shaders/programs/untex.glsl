#include "/libs/compat.glsl"
#include "/libs/encoding.glsl"

#include "/libs/color.glsl"

inout vec4 color;
inout vec3 normal;

uniform int frameCounter;

#ifdef VERTEX

#include "/libs/taa.glsl"
uniform vec2 invWidthHeight;

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);

    gl_Position = mvp_mat * input_pos;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#else

void fragment() {
/* DRAWBUFFERS:4 */
    fragData[0] = uvec3(normalEncode(normal), encodeAlbedoSpecular(color.rgb, vec2(1.0)), packUnorm4x8(vec4(0.0, 0.0, 0.0, 0.0)));
}

#endif