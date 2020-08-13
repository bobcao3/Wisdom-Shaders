#version 420 compatibility
#pragma optimize(on)

#define BUFFERS
#define TRANSFORMATIONS_RESIDUAL
#define VECTORS
#define CLIPPING_PLANE

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"
#include "libs/uniforms.glsl"

uniform float rainStrength;

const bool colortex0MipmapEnabled = true;
const bool colortex2MipmapEnabled = true;

vec3 get_uniform_hemisphere_weighted(vec2 r) {
    float phi = 2.0 * 3.1415926 * r.y;
    float sqrt_rx = fsqrt(r.x);

    return vec3(cos(phi) * sqrt_rx, sin(phi) * sqrt_rx, fsqrt(1.0 - r.x));
}

#include "libs/raytrace.glsl"

const bool colortex3Clear = false;

uniform int biomeCategory;
uniform float wetness;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite_diffuse = vec3(0.0);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;

    vec4 specular = unpackUnorm4x8(gbuffers.a);
    specular.r = clamp(pow(1.0 - specular.r, 2.0), 0.1, 0.9);
    
    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);
    
    if ((specular.a <= 0.05 || specular.a == 1.0) && proj_pos.z < 0.99999) {
        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        float skyLight = pow2(lmcoord.y);
        vec3 Ld = vec3(0.0);

        if (biomeCategory == 16)
        {
            skyLight = 0.3;
        }

        const int num_sspt_rays = 4;
        const float weight_per_ray = 1.0 / float(num_sspt_rays);
        const float num_directions = 4096 * num_sspt_rays;

        float stride = max(2.0, viewHeight / 480.0);
        float noise_sample = fract(bayer64(iuv));

        int sky_lod = clamp(int((1.0 - specular.r + specular.g) * 3.0), 0, 3);

        vec3 mirror_dir = reflect(-V, normal);
        mat3 obj2view = make_coord_space(normal);

        float wetnessMorph = 0.5 * noise(world_pos.xz + cameraPosition.xz);
        wetnessMorph += 1.5 * noise(world_pos.xz * 0.5 + cameraPosition.xz * 0.5);
        wetnessMorph += 2.0 * noise(world_pos.xz * 0.2 + cameraPosition.xz * 0.2);
        wetnessMorph = clamp(wetnessMorph + 1.0, 0.3, 1.0) * wetness * smoothstep(0.9, 0.95, lmcoord.y);

        specular.r = mix(specular.r, 0.3, wetnessMorph);

        for (int i = 0; i < num_sspt_rays; i++) {
            float noiseSeed = noise(vec3(noise_sample, i * 0.1, (frameCounter & 0xFFF) * 0.01));
            vec2 grid_sample = WeylNth(int(noiseSeed * 65536));

            float pdf = 1.0;
            vec3 ray_trace_dir = ImportanceSampleGGX(grid_sample, normal, -V, specular.r, pdf);

            if (dot(ray_trace_dir, normal) < 0.1) continue;

            int lod = 4;
            float start_bias = clamp(0.1 / ray_trace_dir.z, 0.0, 1.0);
            ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, false, stride, 1.44, 2.0, i, lod);
            
            vec3 diffuse = vec3(0.0);
            // vec3 specular = vec3(0.0);
            
            if (reflected != ivec2(-1)) {
                lod = min(3, lod);
                vec3 radiance = texelFetch(colortex0, reflected >> lod, lod).rgb;
                vec3 prevComposite = texelFetch(colortex2, reflected >> lod, lod).rgb;

                diffuse = prevComposite; //(prevComposite + radiance) * 0.5;
            } else {
                vec3 world_dir = mat3(gbufferModelViewInverse) * ray_trace_dir;
                float sun_disc_occulusion = 1.0 - smoothstep(0.9, 0.999, abs(dot(ray_trace_dir, sunPosition * 0.01)));
                vec3 skyRadiance = skyLight * texture(gaux4, project_skybox2uv(world_dir), sky_lod).rgb * sun_disc_occulusion;

                diffuse = skyRadiance;
            }

            Ld += diffuse * getF(specular.g, dot(V, normal));
        }
        
        Ld *= weight_per_ray;

        vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
        vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
        proj_pos_prev.xyz /= proj_pos_prev.w;

        vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5) + 0.5 * invWidthHeight;
        vec4 history_d = texture(colortex3, prev_uv);
        
        if (isnan(Ld.r) || isnan(Ld.g) || isnan(Ld.b)) Ld = vec3(0.0);
        
        if (prev_uv.x <= 0.0 || prev_uv.x >= 1.0 || prev_uv.y <= 0.0 || prev_uv.y >= 1.0)
        {
            composite_diffuse = Ld;
        }
        else
        {
            float mix_weight = 0.1;
            float history_depth = proj_pos_prev.z * 0.5 + 0.5;
            float depth_difference = abs(history_d.a - history_depth) / history_depth;
            if (depth_difference > 0.001) {
                mix_weight = 1.0;
            }

            composite_diffuse = mix(history_d.rgb, Ld, mix_weight);
        }
        
    } else {
        vec3 dir = normalize(world_pos);
        composite_diffuse = texture(gaux4, project_skybox2uv(dir)).rgb;
    }

/* DRAWBUFFERS:3 */
    gl_FragData[0] = vec4(composite_diffuse, depth);
}