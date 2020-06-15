#include "compat.glsl"

uniform int frameCounter;

#ifdef VERTEX

#include "taa.glsl"
uniform vec2 invWidthHeight;

out vec4 vcolor;
out vec2 vuv;
out vec4 shadow_view_pos;
out vec3 vnormal;
out float blockId;

uniform vec3 shadowLightPosition;
uniform vec3 upPosition;

attribute vec4 mc_Entity;

void main() {
    vec4 input_pos = gl_Vertex;

    vuv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    vcolor = gl_Color;
    vnormal = gl_NormalMatrix * gl_Normal;

    blockId = mc_Entity.x;

    if (mc_Entity.y == 0) blockId = 8001;

    shadow_view_pos = gl_ModelViewMatrix * input_pos;
}

#elif defined(GEOMETRY)

#extension GL_ARB_geometry_shader4 : enable
const int maxVerticesOut = 12;

in vec4 vcolor[3];
in vec2 vuv[3];
in vec4 shadow_view_pos[3];
in vec3 vnormal[3];
in float blockId[3];

out vec4 color;
out vec2 uv;
out vec3 normal;
out flat int cascade;

uniform mat4 shadowProjection;
uniform mat4 shadowModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform float aspectRatio;
uniform float far;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

float max_axis(in vec2 v) {
    v = abs(v);
    return max(v.x, v.y);
}

float square(float a) {
    return a * a;
}

bool intersect(vec3 orig, vec3 D) { 
    // Test whether a line crosses the view frustum
    
    float tan_theta_h = 1.0 / gbufferProjection[1][1];
    float tan_theta = sqrt(square(tan_theta_h) + square(tan_theta_h * aspectRatio));
    float theta = atan(tan_theta);
    float cos_theta = cos(theta);
    float cos2_theta = cos_theta * cos_theta;

    vec3 C = vec3(0.0, 0.0, 16.0);
    vec3 V = vec3(0.0, 0.0, -1.0);
    vec3 CO = orig - C;

    if (dot(normalize(CO), V) > cos_theta) return true;

    float a = square(dot(D, V)) - cos2_theta;
    float b = 2.0 * (dot(D, V) * dot(CO, V) - dot(D, CO) * cos2_theta);
    float c = square(dot(CO, V)) - dot(CO, CO) * cos2_theta;

    float det = b * b - 4.0 * a * c;

    if (det < 0) return false;

    det = sqrt(det);
    float t1 = (-b - det) / (2. * a);
    float t2 = (-b + det) / (2. * a);

    float t = t1;
    if (t < 0.0 || t2 > 0.0 && t2 < t) t = t2;
    if (t < 0.0) return false;

    vec3 CP = orig + t * D - C;
    float h = dot(CP, V);
    if (h < 0.0 || h > far) return false;

    return true;
}

void main() {
    if (vnormal[0].z + vnormal[1].z + vnormal[2].z >= 0 && blockId[0] != 18 && blockId[0] != 31 && blockId[0] != 79 && blockId[0] != 8001) return;

    vec4 sview_center = (shadow_view_pos[0] + shadow_view_pos[1] + shadow_view_pos[2]) * (1.0 / 3.0);

    vec4 cam_view_pos = (shadowModelViewInverse * sview_center);
    if (cam_view_pos.y + cameraPosition.y <= 0.5) return;
    cam_view_pos = gbufferModelView * cam_view_pos;

    if (!intersect(cam_view_pos.xyz, -shadowLightPosition * 0.01)) return;

    vec4 emit_pos[3];

    for (int n = 0; n < 4; n++) {
        bool emit = true;
        for (int i = 0; i < 3; i++) {
            vec4 proj_pos = shadowProjection * shadow_view_pos[i];

            if (n == 0) {
                // Top Left
                if (max_axis(proj_pos.xy) > 0.6) emit = false;
                proj_pos.xy *= 1.0;
                proj_pos.z *= 0.5;
                proj_pos.xy += vec2(-0.5, 0.5);
            } else if (n == 1) {
                // Top Right
                if (max_axis(proj_pos.xy) > 2.2 || max_axis(proj_pos.xy) < 0.4) emit = false;
                proj_pos.xy *= 0.25;
                proj_pos.z *= 0.5;
                proj_pos.xy += vec2(0.5, 0.5);
            } else if (n == 2) {
                // Bottom Left
                if (max_axis(proj_pos.xy) > 4.4 || max_axis(proj_pos.xy) < 1.8) emit = false;
                proj_pos.xy *= 0.125;
                proj_pos.z *= 0.5;
                proj_pos.xy += vec2(-0.5, -0.5);
            } else if (n == 3) {
                // Bottom Right
                if (max_axis(proj_pos.xy) < 3.6) emit = false;
                proj_pos.xy *= 0.03125;
                proj_pos.z *= 0.25;
                proj_pos.xy += vec2(0.5, -0.5);
            }

            if (emit) {
                emit_pos[i] = proj_pos;
            }
        }

        if (emit) {
            for (int i = 0; i < 3; i++) {
                gl_Position = emit_pos[i];
                color = vcolor[i];
                uv = vuv[i];
                normal = normalize(vnormal[i]);
                cascade = n;
                EmitVertex();
            }
            EndPrimitive();
        }
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