#version 420 compatibility
#pragma optimize(on)

#define BUFFERS
#define VECTORS
#define CLIPPING_PLANE
#define LQ_ATMOS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"
#include "configs.glsl"

#include "libs/uniforms.glsl"
#include "libs/atmosphere.glsl"

uniform vec3 fogColor;
uniform int biomeCategory;

float densities(float h)
{
    if (biomeCategory != 16)
    {
        float d = clamp(2.0 * exp2(-h / 128.0f), 0.0, 2.0);

        d += rainStrength * 8.0;

        return d;
    }
    else
    {
        float d = 2.0 * clamp(exp2(-h / 32.0f), 0.0, 2.0);

        return d;
    }
}

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);
    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);
    vec3 nwpos = normalize(world_pos);

    vec3 color = texelFetch(colortex0, iuv, 0).rgb;

    float distinction_distance = 4096.0;

    /*
    if (proj_pos.z > 0.99999 && world_pos.y < -0.01)
    {
        float multiplier = 1.0 / world_pos.y * (cameraPosition.y - 61.0);
        world_pos *= multiplier;
        view_pos *= multiplier;

        vec3 reflectDir = vec3(nwpos.x, -nwpos.y, nwpos.z);
        color = fresnelSchlick(-nwpos.y, vec3(0.02)) * texture(gaux4, project_skybox2uv(reflectDir)).rgb;
    }
    */

    if (biomeCategory == 16.0)
    {
        distinction_distance = 512.0;
    }

    float distinction = clamp(length(view_pos) / distinction_distance, 0.0, 1.0);
    float actualDistinction = 0.0;

    float dither = fract(hash(frameCounter & 0xFFFF) + bayer16(iuv));

    vec3 spos_start = world2shadowProj(vec3(0.0));
    vec3 spos_end = world2shadowProj(world_pos);

    float accumulation = 0.0;

    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
    vec3 fog;
    
    if (biomeCategory != 16)
        fog = scatter(vec3(0.0, cameraPosition.y, 0.0), normalize(world_pos), world_sun_dir, 64.0 * distinction_distance * distinction);
    else
        fog = fromGamma(fogColor);

    for (int i = 0; i < 3; i++)
    {
        float t = (float(i) + dither) * 0.3333;
        vec3 spos = t * (spos_end - spos_start) + spos_start;
        vec3 wpos = t * world_pos;

        float s, ds;
        vec3 spos_cascaded = shadowProjCascaded(spos, s, ds);

        float shadow = 1.0;
        
        if (biomeCategory != 16 && spos_cascaded != vec3(-1))
        {
            shadow = shadowTexSmooth(shadowtex1, spos_cascaded, ds, 0.0);
        }

        float density = distinction * densities(wpos.y + cameraPosition.y);
        actualDistinction += density;
        accumulation += density * shadow * exp2(-(1.0 - t) * distinction);
    }

    color *= exp2(-actualDistinction);
    color += accumulation * fog;

/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}