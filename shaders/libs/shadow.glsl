#include "compat.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec2 uv;

const int countInstances = 4;

uniform int instanceId;

#ifdef VERTEX

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

uniform mat4 gbufferModelView;

float max_axis(in vec2 v) {
    v = abs(v);
    return max(v.x, v.y);
}

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    vec4 proj_pos = mvp_mat * input_pos;

    if (instanceId == 0) {
        // Top Left
        if (max_axis(proj_pos.xy) > 0.6) proj_pos.z = 1000000.0;
        proj_pos.xy *= 1.0;
        proj_pos.z *= 0.5;
        proj_pos.xy += vec2(-0.5, 0.5);
    } else if (instanceId == 1) {
        // Top Right
        if (max_axis(proj_pos.xy) > 2.2) proj_pos.z = 1000000.0;
        proj_pos.xy *= 0.25;
        proj_pos.z *= 0.5;
        proj_pos.xy += vec2(0.5, 0.5);
    } else if (instanceId == 2) {
        // Bottom Left
        if (max_axis(proj_pos.xy) > 4.4) proj_pos.z = 1000000.0;
        proj_pos.xy *= 0.125;
        proj_pos.z *= 0.5;
        proj_pos.xy += vec2(-0.5, -0.5);
    } else if (instanceId == 3) {
        // Bottom Right
        proj_pos.xy *= 0.03125;
        proj_pos.z *= 0.25;
        proj_pos.xy += vec2(0.5, -0.5);
    }


    gl_Position = proj_pos;

    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
}

#else

uniform sampler2D tex;

#include "./../configs.glsl"

void fragment() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    
    if (instanceId == 0) {
        if (iuv.x > shadowMapQuadRes || iuv.y < shadowMapQuadRes) discard;
    } else if (instanceId == 1) {
        if (iuv.x < shadowMapQuadRes || iuv.y < shadowMapQuadRes) discard;
    } else if (instanceId == 2) {
        if (iuv.x > shadowMapQuadRes || iuv.y > shadowMapQuadRes) discard;
    } else if (instanceId == 3) {
        if (iuv.x < shadowMapQuadRes || iuv.y > shadowMapQuadRes) discard;
    }

    gl_FragData[0] = color * texture(tex, uv);
}

#endif