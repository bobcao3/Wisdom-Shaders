#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

flat out vec3 sun_I;
flat out vec3 moon_I;

#define DISABLE_MIE

#include "/libs/transform.glsl"
#include "/libs/atmosphere.glsl"
#include "/libs/color.glsl"

#define VECTORS
#define CLIPPING_PLANE
#include "/libs/uniforms.glsl"

flat out vec3 ambient_left;
flat out vec3 ambient_right;
flat out vec3 ambient_front;
flat out vec3 ambient_back;
flat out vec3 ambient_up;
flat out vec3 ambient_down;

uniform int biomeCategory;

uniform vec3 fogColor;

void main() {
    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
    float fade = smoothstep(0.0, 0.05, abs(world_sun_dir.y));

    float sunCoverage = texture(gaux4, project_skybox2uv(world_sun_dir)).a;
    float moonCoverage = texture(gaux4, project_skybox2uv(-world_sun_dir)).a;

    vec3 sunColor = texture(gaux4, project_skybox2uv(world_sun_dir)).rgb;
    vec3 moonColor = texture(gaux4, project_skybox2uv(-world_sun_dir)).rgb;

    sun_I = sunCoverage * sunColor * fade;
    moon_I = moonCoverage * moonColor * fade;

    if (biomeCategory != 16) {
        ambient_left = scatter(vec3(0.0, cameraPosition.y, 0.0), vec3(1.0, 0.0, 0.0), world_sun_dir, Ra, 0.1, cameraPosition).rgb;
        ambient_right = scatter(vec3(0.0, cameraPosition.y, 0.0), vec3(-1.0, 0.0, 0.0), world_sun_dir, Ra, 0.1, cameraPosition).rgb;
        ambient_front = scatter(vec3(0.0, cameraPosition.y, 0.0), vec3(0.0, 0.0, 1.0), world_sun_dir, Ra, 0.1, cameraPosition).rgb;
        ambient_back = scatter(vec3(0.0, cameraPosition.y, 0.0), vec3(0.0, 0.0, -1.0), world_sun_dir, Ra, 0.1, cameraPosition).rgb;
        ambient_up = scatter(vec3(0.0, cameraPosition.y, 0.0), vec3(0.0, 1.0, 0.0), world_sun_dir, Ra, 0.1, cameraPosition).rgb;
        ambient_down = scatter(vec3(0.0, cameraPosition.y, 0.0), vec3(0.0, -1.0, 0.0), world_sun_dir, Ra, 0.1, cameraPosition).rgb;
    } else {
        vec3 ambient = fromGamma(fogColor);
        ambient_left = ambient;
        ambient_right = ambient;
        ambient_front = ambient;
        ambient_back = ambient;
        ambient_up = ambient;
        ambient_down = ambient;
    }

    gl_Position = ftransform();
}