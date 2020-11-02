#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

#define BUFFERS
#define VECTORS
#define CLIPPING_PLANE

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

uniform int isEyeInWater;

#define VL_SAMPLES 6 // [2 4 6 8 12]

float densities(float h)
{
    if (biomeCategory != 16)
    {
        float d = clamp(3.0 * exp2(-h / 64.0f) - 0.2, 0.0, 2.0) * (4.0 + rainStrength * 8.0) * 2.0;

        return d;
    }
    else
    {
        float d = 4.0 * clamp(exp2(-h / 32.0f), 0.0, 2.0) * (isEyeInWater == 2 ? 10.0 : 1.0);

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

    if (isEyeInWater == 1 && depth == texelFetch(depthtex1, iuv, 0).r)
    {
        // Underwater FX
        vec2 lmcoord = unpackUnorm4x8(texelFetch(colortex4, iuv, 0).b).st;

        float waterDepth = (0.96 - lmcoord.y) * 16.0;

        float absorption = min(1.0, waterDepth * 0.03125);
        absorption = 2.0 / (absorption + 1.0) - 1.0;
        absorption *= absorption;
        vec3 transmittance = pow(vec3(absorption), vec3(3.0, 0.8, 1.0));
        color.rgb *= transmittance;
    }

    // Atmosphere
    if (true)
    {
        float distinction_distance = 4096.0;

        if (biomeCategory == 16.0)
        {
            distinction_distance = 512.0;
        }

        if (isEyeInWater == 1)
        {
            distinction_distance = 50.0;
        }

        float distinction = clamp(length(view_pos) / distinction_distance, 0.0, 1.0);
        float actualDistinction = 0.0;

        float dither = fract(hash(frameCounter & 0xFFFF) + bayer16(iuv)) * 2.0 - 1.0;

        vec3 spos_start = world2shadowProj(vec3(0.0));
        vec3 spos_end = world2shadowProj(world_pos);

        float accumulation = 0.0;

        vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
        vec3 fog;

        float nseed = fract(texelFetch(colortex1, iuv & 0xFF, 0).r + texelFetch(colortex1, ivec2(frameCounter) & 0xFF, 0).r) - 0.5;
        
        if (biomeCategory != 16)
            fog = scatter(vec3(0.0, cameraPosition.y, 0.0), normalize(world_pos), world_sun_dir, 8192 * max(0.5, distinction), nseed, cameraPosition + world_pos).rgb;
        else
            fog = fromGamma(fogColor);

        for (int i = 0; i < VL_SAMPLES; i++)
        {
            float t = (float(i) + nseed + 0.5) / float(VL_SAMPLES);
            vec3 spos = t * (spos_end - spos_start) + spos_start;
            vec3 wpos = t * world_pos;

            float shadow = 1.0;

            if (depth < 0.99999 && biomeCategory != 16)
            {
                float s, ds;
                vec3 spos_cascaded = shadowProjCascaded(spos, s, ds);

                if (spos_cascaded != vec3(-1))
                {
                    shadow = shadowTexSmooth(shadowtex1, spos_cascaded, ds, 0.0);
                }
            }

            float density = distinction * densities(wpos.y + cameraPosition.y) / float(VL_SAMPLES);
            actualDistinction += density;
            accumulation += exp2(-actualDistinction) * shadow * density;
        }

        color *= exp2(-actualDistinction);
        color += clamp(accumulation, 0.0, 1.0) * fog;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}