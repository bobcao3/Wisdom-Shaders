#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

#define BUFFERS

#include "/libs/encoding.glsl"
#include "/libs/sampling.glsl"
#include "/libs/bsdf.glsl"
#include "/libs/transform.glsl"
#include "/libs/color.glsl"
#include "/libs/noise.glsl"

#define VECTORS
#define CLIPPING_PLANE
#define TRANSFORMATIONS_RESIDUAL
#include "/libs/uniforms.glsl"

flat in vec3 sun_I;
flat in vec3 moon_I;

#define CLOUDS

#include "/libs/raytrace.glsl"
#include "/libs/atmosphere.glsl"

#define PCSS
// #define REDUCE_GHOSTING

uniform int biomeCategory;

const bool colortex2MipmapEnabled = true;
const bool colortex3Clear = false;

#define NUM_SSPT_RAYS 4 // [1 2 4 8 16 32]

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec3 gbuffers = texelFetch(colortex4, iuv, 0).rgb;

    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    vec2 specular;
    decodeAlbedoSpecular(gbuffers.g, color.rgb, specular);
    
    specular.r = (1.0 - specular.r * specular.r);
    
    vec3 normal = normalDecode(gbuffers.r);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    float subsurface = decoded_b.b * 16.0;

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);

    vec3 composite_diffuse = vec3(0.0);

    if (proj_pos.z < 0.99999) {
        // Direct Lighting
        vec3 sun_vec = shadowLightPosition * 0.01;
        float shadow;
        vec3 L = vec3(0.0);
        vec3 F0 = getF0(color.rgb, specular.g);

        if (biomeCategory != 16) {
            //int cascade = int(clamp(floor(log2(max(abs(world_pos.x), abs(world_pos.z)) / 8.0)), 0.0, 4.0));
            float scale;
            vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * 0.007 * abs(view_pos.z));

            float shadow_sampled_depth;
#ifdef PCSS
            float shadow_radius = getShadowRadiusPCSS(shadowtex1, shadow_proj_pos, shadow_sampled_depth, iuv);
#else
            const float shadow_radius = 0.001;
#endif
            float shadow = shadowFiltered(shadowtex1, shadow_proj_pos, shadow_sampled_depth, shadow_radius, iuv);

            vec3 b = normalize(cross(sun_vec, normal));
            vec3 t = cross(normal, b);

            // if (depth > 0.7) {
            //     int lod = 0;
            //     float rt_contact_shadow = float(raytrace(view_pos, vec2(iuv), sun_vec, 2.0, 1.0, 0.01, 0, lod) != ivec2(-1));
            //     // rt_contact_shadow *= smoothstep(0.20, 0.35, abs(dot(sun_vec, normal)));

            //     shadow = min(shadow, 1.0 - rt_contact_shadow);
            // }
            
            vec3 spos_diff = vec3(shadow_proj_pos.xy, max(shadow_proj_pos.z - shadow_sampled_depth, 0.0));
            float subsurface_depth = 1.0 - smoothstep(0.0, subsurface + pow(max(0.0, dot(normalize(view_pos), sun_vec)), 8.0), sposLinear(spos_diff) * 32.0);

            if (subsurface > 0.0) {
                shadow = mix(min(subsurface_depth, 1.0), shadow, min(1.0, subsurface));
            } else {
                shadow = shadow;
            }

            L = max(vec3(0.0), (sun_I + moon_I) * shadow);
            L = brdf_ggx_oren_schlick(color.rgb, L, specular.r, specular.g, subsurface, F0, sun_vec, normal, V);

            // L = vec3(abs(dot(normal, L)));

            color.a = shadow;
        }

        const vec3 torch1900K = pow(vec3(255.0, 147.0, 41.0) / 255.0, vec3(2.2));
        const vec3 torch3500K = pow(vec3(255.0, 196.0, 137.0) / 255.0, vec3(2.2));
        const vec3 torch5500K = pow(vec3(255.0, 236.0, 224.0) / 255.0, vec3(2.2));

        float blockLight = pow(lmcoord.x, 6.0);
        vec3 blockLightColor = torch1900K;
        if (biomeCategory == 16)
        {
            blockLightColor = torch3500K;
        }
        vec3 block_L = blockLightColor * blockLight; // 10000 lux

        float emmisive = decoded_b.a;
        if (emmisive <= (254.5 / 255.0) && emmisive > 0.05) {
            color.rgb *= emmisive; // Max at 10000 lux
        } else {
            color.rgb = L + diffuse_brdf_ggx_oren_schlick(color.rgb, block_L, specular.r, specular.g, F0, normal, V);
        }

        // SSPT
        if (emmisive <= 0.05 || emmisive >= 0.995)
        {
            float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
            float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

            float skyLight = pow2(lmcoord.y);
            vec3 Ld = vec3(0.0);

            if (biomeCategory == 16)
            {
                skyLight = 0.5;
            }

            const float weight_per_ray = 1.0 / float(NUM_SSPT_RAYS);
            const float num_directions = 4096 * NUM_SSPT_RAYS;

            float stride = max(2.0, viewHeight / 480.0);
            float noise_sample = fract(texelFetch(colortex1, iuv & 0xFF, 0).r + texelFetch(colortex1, ivec2(frameCounter) & 0xFF, 0).r);

            int sky_lod = clamp(int((1.0 - specular.r + specular.g) * 3.0), 0, 3);

            vec3 mirror_dir = reflect(-V, normal);
            mat3 obj2view = make_coord_space(normal);

            for (int i = 0; i < NUM_SSPT_RAYS; i++) {
                float noiseSeed = noise_sample * 65535 * NUM_SSPT_RAYS + i;
                vec2 grid_sample = WeylNth(int(noiseSeed));

                float pdf = 1.0;
                vec3 ray_trace_dir = ImportanceSampleGGX(grid_sample, normal, -V, specular.r, pdf);

                if (dot(ray_trace_dir, normal) < 0.05) continue;

                int lod = 4;
                float start_bias = clamp(0.1 / ray_trace_dir.z, 0.0, 1.0);
                ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, stride, 1.44, 2.0, i, lod);
                
                vec3 diffuse = vec3(0.0);
                
                if (reflected != ivec2(-1)) {
                    lod = min(3, lod);
                    vec3 prevComposite = texelFetch(colortex2, reflected >> lod, lod).rgb;

                    diffuse = prevComposite;
                } else {
                    vec3 world_dir = mat3(gbufferModelViewInverse) * ray_trace_dir;
                    vec3 skyRadiance = skyLight * texture(gaux4, project_skybox2uv(world_dir), sky_lod).rgb;

                    diffuse = skyRadiance;
                }

                Ld += diffuse * getF(specular.g, dot(V, normal));
            }
            
            Ld *= weight_per_ray;

            vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
            vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
            proj_pos_prev.xyz /= proj_pos_prev.w;

            vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5);
            ivec2 iprev_uv = ivec2(prev_uv);
            prev_uv += 0.5 * invWidthHeight;

            if (isnan(Ld.r) || isnan(Ld.g) || isnan(Ld.b)) Ld = vec3(0.0);
            
            if (prev_uv.x <= 0.0 || prev_uv.x >= 1.0 || prev_uv.y <= 0.0 || prev_uv.y >= 1.0)
            {
                composite_diffuse = Ld;
            }
            else
            {
                vec4 history_d = texture(colortex3, prev_uv);
            
                #ifdef REDUCE_GHOSTING
                float mix_weight = 0.2;
                #else
                float mix_weight = 0.1;
                #endif
        
                float history_depth = proj_pos_prev.z * 0.5 + 0.5;
                float depth_difference = abs(history_d.a - history_depth) / history_depth;
                if (depth_difference > 0.001) {
                    mix_weight = 1.0;
                }

                composite_diffuse = mix(history_d.rgb, Ld, mix_weight);
            }
        }
    } else {
        vec3 dir = normalize(world_pos);
        vec2 polarCoord = project_skybox2uv(dir);

        if (biomeCategory != 16) {
            color.rgb = fromGamma(texelFetch(colortex0, iuv, 0).rgb) * 3.14;
            color.rgb += sun_I * 6.283 * smoothstep(0.9999, 0.99991, dot(normalize(view_pos), sunPosition * 0.01));

            color.rgb += starField(dir * 2.0) * vec3(1.0, 0.6, 0.4);
            color.rgb += starField(dir) * vec3(0.7, 0.8, 1.3);
            color.rgb += starField(dir * 0.5);

            color.rgb = mix(color.rgb, moon_I * 8.0, smoothstep(0.9996, 0.99961, dot(normalize(view_pos), moonPosition * 0.01)));
        }

#ifdef CLOUDS
        vec4 atmosphere = bicubicSample(gaux4, vec2(iuv) * invWidthHeight * vec2(0.25, 0.5) + vec2(0.5, 0.0));
        color.rgb *= atmosphere.a;
        color.rgb += atmosphere.rgb;
#else
        color.rgb += bicubicSample(gaux4, polarCoord).rgb;
#endif

        composite_diffuse = color.rgb;
    }

/* DRAWBUFFERS:03 */
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(composite_diffuse, depth);
}