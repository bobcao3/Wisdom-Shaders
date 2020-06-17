#version 420 compatibility
#pragma optimize(on)

flat out vec3 sun_I;

#include "libs/transform.glsl"
#include "libs/atmosphere.glsl"
#include "libs/color.glsl"

#define VECTORS
#define CLIPPING_PLANE
#include "libs/uniforms.glsl"

void main() {
    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
    sun_I = texture(gaux4, project_skybox2uv(world_sun_dir)).rgb * (1.0 - cloud_coverage * 0.97);

    gl_Position = ftransform();
}