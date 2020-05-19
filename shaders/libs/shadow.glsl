#include "compat.glsl"

uniform int frameCounter;

#ifdef VERTEX

#include "taa.glsl"
uniform vec2 invWidthHeight;

out vec4 vcolor;
out vec2 vuv;
out vec4 vpos;
out vec3 vnormal;
out float blockId;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

uniform mat4 gbufferModelView;

attribute vec4 mc_Entity;

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    vec4 proj_pos = mvp_mat * input_pos;

    vpos = proj_pos;
    vuv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    vcolor = gl_Color;
    vnormal = normalize(gl_NormalMatrix * gl_Normal);

    blockId = mc_Entity.x;

    if (mc_Entity.y == 0) blockId = 8001;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#elif defined(GEOMETRY)

#extension GL_ARB_geometry_shader4 : enable
const int maxVerticesOut = 12;

in vec4 vcolor[3];
in vec2 vuv[3];
in vec4 vpos[3];
in vec3 vnormal[3];
in float blockId[3];

out vec4 color;
out vec2 uv;
out flat int cascade;

float max_axis(in vec2 v) {
    v = abs(v);
    return max(v.x, v.y);
}

void main() {
    if (vnormal[0].z + vnormal[1].z + vnormal[2].z >= 0 && blockId[0] != 18 && blockId[0] != 31 && blockId[0] != 79 && blockId[0] != 8001) return;

    for (int n = 0; n < 4; n++) {
        for (int i = 0; i < 3; i++) {
            cascade = n;
    
            vec4 proj_pos = vpos[i];

            if (n == 0) {
                // Top Left
                if (max_axis(proj_pos.xy) > 0.6) proj_pos.z = 1000000.0;
                proj_pos.xy *= 1.0;
                proj_pos.z *= 0.5;
                proj_pos.xy += vec2(-0.5, 0.5);
            } else if (n == 1) {
                // Top Right
                if (max_axis(proj_pos.xy) > 2.2) proj_pos.z = 1000000.0;
                proj_pos.xy *= 0.25;
                proj_pos.z *= 0.5;
                proj_pos.xy += vec2(0.5, 0.5);
            } else if (n == 2) {
                // Bottom Left
                if (max_axis(proj_pos.xy) > 4.4) proj_pos.z = 1000000.0;
                proj_pos.xy *= 0.125;
                proj_pos.z *= 0.5;
                proj_pos.xy += vec2(-0.5, -0.5);
            } else if (n == 3) {
                // Bottom Right
                proj_pos.xy *= 0.03125;
                proj_pos.z *= 0.25;
                proj_pos.xy += vec2(0.5, -0.5);
            }

            gl_Position = proj_pos;
            color = vcolor[i];
            uv = vuv[i];
            EmitVertex();
        }

        EndPrimitive();
    }
}

#else

in vec4 color;
in vec3 normal;
in vec2 uv;
in flat int cascade;

uniform sampler2D tex;

#include "./../configs.glsl"

void fragment() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    
    if (cascade == 0) {
        if (iuv.x > shadowMapQuadRes || iuv.y < shadowMapQuadRes) discard;
    } else if (cascade == 1) {
        if (iuv.x < shadowMapQuadRes || iuv.y < shadowMapQuadRes) discard;
    } else if (cascade == 2) {
        if (iuv.x > shadowMapQuadRes || iuv.y > shadowMapQuadRes) discard;
    } else if (cascade == 3) {
        if (iuv.x < shadowMapQuadRes || iuv.y > shadowMapQuadRes) discard;
    }

    gl_FragData[0] = color * texture(tex, uv);
}

#endif