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

#define CLOUD_SHADOW

void main() {
    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
    float fade = smoothstep(0.0, 0.1, abs(world_sun_dir.y));

    float sunCoverage = texture(gaux4, project_skybox2uv(world_sun_dir)).a;
    float moonCoverage = texture(gaux4, project_skybox2uv(-world_sun_dir)).a;

    vec3 sunColor = texture(gaux4, project_skybox2uv(world_sun_dir)).rgb;
    vec3 moonColor = texture(gaux4, project_skybox2uv(-world_sun_dir)).rgb;

#ifdef CLOUD_SHADOW
    sun_I = sunColor * fade;
    moon_I = moonColor * fade;
#else
    sun_I = sunCoverage * sunColor * fade;
    moon_I = moonCoverage * moonColor * fade;
#endif

    gl_Position = ftransform();
}