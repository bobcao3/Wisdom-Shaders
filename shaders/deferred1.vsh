#version 420 compatibility
#pragma optimize(on)

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
    sun_I = texture(gaux4, project_skybox2uv(world_sun_dir)).rgb * (1.0 - cloud_coverage * 0.9) * fade;
    moon_I = texture(gaux4, project_skybox2uv(-world_sun_dir)).rgb * (1.0 - cloud_coverage * 0.9) * fade;

    gl_Position = ftransform();
}