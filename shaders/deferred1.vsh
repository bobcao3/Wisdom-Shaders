#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

flat out vec3 sun_I;
flat out vec3 moon_I;

#include "/libs/transform.glsl"
#include "/libs/atmosphere.glsl"
#include "/libs/color.glsl"

#define VECTORS
#define CLIPPING_PLANE
#include "/libs/uniforms.glsl"

void main() {
    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
    float fade = smoothstep(0.0, 0.05, abs(world_sun_dir.y));

    float sunCoverage = texture(gaux4, project_skybox2uv(world_sun_dir)).a;
    float moonCoverage = texture(gaux4, project_skybox2uv(-world_sun_dir)).a;

    vec3 sunColor = scatter(vec3(0.0, cameraPosition.y, 0.0), world_sun_dir, world_sun_dir, Ra, 0.1).rgb;
    vec3 moonColor = scatter(vec3(0.0, cameraPosition.y, 0.0), -world_sun_dir, world_sun_dir, Ra, 0.1).rgb;

    sun_I = sunCoverage * sunColor * fade;
    moon_I = moonCoverage * moonColor * fade;

    gl_Position = ftransform();
}