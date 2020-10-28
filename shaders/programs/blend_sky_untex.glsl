#include "/libs/compat.glsl"
#include "/libs/encoding.glsl"

#include "/libs/color.glsl"

inout vec4 color;

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

    vec4 position = model_view_mat * input_pos;

    gl_Position = mvp_mat * input_pos;
    gl_FogFragCoord = length(position.xyz);

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#else

uniform sampler2D tex;

uniform float near;
uniform float far;

uniform int fogMode;

#include "/libs/noise.glsl"

void fragment() {
/* DRAWBUFFERS:0 */
    float saturation = abs(color.r - color.g) + abs(color.r - color.b) + abs(color.g - color.b);
	float luma = dot(color.rgb,vec3(0.2126, 0.7152, 0.0722));

    gl_FragData[0] = vec4(0.0, 0.0, 0.0, 1.0);
}

#endif