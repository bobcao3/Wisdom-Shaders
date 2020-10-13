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
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

const bool colortex2MipmapEnabled = true;
const bool colortex3Clear = false;

#define NUM_SSPT_RAYS 4 // [1 2 4 8 16 32]

vec3 sampleHistory(ivec2 iuv, float history_depth, vec3 Ld)
{
    vec4 history_d = texelFetch(colortex3, iuv, 0);
            
    #ifdef REDUCE_GHOSTING
    float mix_weight = 0.15;
    #else
    float mix_weight = 0.07;
    #endif

    float depth_difference = abs(linearizeDepth(history_d.a) - history_depth) / history_depth;
    if (depth_difference > 0.05) {
        mix_weight = 1.0;
    }

    return mix(history_d.rgb, Ld, mix_weight);
}

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
    specular.g = clamp(specular.g, 0.01, 0.99);
    
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
            vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * (depth < 0.7 ? 0.5 : 0.02));

            float shadow_sampled_depth;
            bool skipShadow = false;
            float shadow = 1.0;
#ifdef PCSS
            float shadow_radius = getShadowRadiusPCSS(shadowtex1, shadow_proj_pos, shadow_sampled_depth, iuv, skipShadow, shadow);
#else
            const float shadow_radius = 0.001;
#endif
            if (!skipShadow)
            {
                shadow = shadowFiltered(shadowtex1, shadow_proj_pos, shadow_sampled_depth, shadow_radius, iuv);
            }

            vec3 b = normalize(cross(sun_vec, normal));
            vec3 t = cross(normal, b);
            
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

        #define BLOCKLIGHT_R 1.0 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
        #define BLOCKLIGHT_G 0.35 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
        #define BLOCKLIGHT_B 0.1 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
        #define EMMISIVE_BRIGHTNESS 1.2 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]

        vec3 blockLightColor = vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B);

        float blockLight = pow(lmcoord.x, 6.0);
        vec3 block_L = blockLightColor * blockLight; // 10000 lux

        float view_distance = length(view_pos);
        vec3 hand_L = blockLightColor * (float(max(heldBlockLightValue, heldBlockLightValue2)) / 12.0 / ((view_distance + 1.0) * (view_distance + 1.0)));

        float emmisive = decoded_b.a;
        if (emmisive <= (254.5 / 255.0) && emmisive > 0.05) {
            color.rgb *= emmisive * EMMISIVE_BRIGHTNESS; // Max at 10000 lux
        } else {
            color.rgb = L
             + diffuse_brdf_ggx_oren_schlick(color.rgb, block_L, specular.r, specular.g, F0, normal, V)
             + brdf_ggx_oren_schlick(color.rgb, hand_L, specular.r, specular.g, subsurface, F0, V, normal, V);
        }

        // SSPT
        if ((emmisive <= 0.05 || emmisive >= 0.995))
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
                ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, stride, 1.44, 0.3, i, lod);
                
                vec3 diffuse = vec3(0.0);
                
                if (reflected != ivec2(-1) && depth > 0.7) {
                    lod = min(3, lod);
                    vec3 prevComposite = texelFetch(colortex2, reflected >> lod, lod).rgb;

                    diffuse = prevComposite;
                } else {
                    vec3 world_dir = mat3(gbufferModelViewInverse) * ray_trace_dir;
                    vec3 skyRadiance = skyLight * texture(gaux4, project_skybox2uv(world_dir), sky_lod).rgb;

                    diffuse = min(skyRadiance, vec3(1.0));
                }

                Ld += diffuse * clamp(getF(specular.g, dot(V, normal)), vec3(0.0), vec3(1.0));
            }
            
            Ld *= weight_per_ray;

            vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
            vec4 view_pos_prev = gbufferPreviousModelView * world_pos_prev;
            vec4 proj_pos_prev = gbufferPreviousProjection * view_pos_prev;
            proj_pos_prev.xyz /= proj_pos_prev.w;

            vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5);

            if (depth < 0.7)
            {
                prev_uv = uv;
            }

            vec2 prev_uv_texels = prev_uv * vec2(viewWidth, viewHeight);
            vec2 iprev_uv = floor(prev_uv_texels);
            prev_uv += 0.5 * invWidthHeight;

            Ld = clamp(Ld, vec3(0.0), vec3(10.0));
            
            if (prev_uv.x <= 0.001 || prev_uv.x >= 0.999 || prev_uv.y <= 0.001 || prev_uv.y >= 0.999)
            {
                composite_diffuse = Ld;
            }
            else
            {
                float history_depth = linearizeDepth(view_pos_prev.z);
                
                vec3 s00 = sampleHistory(ivec2(iprev_uv), history_depth, Ld);
                vec3 s01 = sampleHistory(ivec2(iprev_uv) + ivec2(0, 1), history_depth, Ld);
                vec3 s10 = sampleHistory(ivec2(iprev_uv) + ivec2(1, 0), history_depth, Ld);
                vec3 s11 = sampleHistory(ivec2(iprev_uv) + ivec2(1, 1), history_depth, Ld);

                composite_diffuse = mix(
                    mix(s00, s10, prev_uv_texels.x - iprev_uv.x),
                    mix(s01, s11, prev_uv_texels.x - iprev_uv.x),
                    prev_uv_texels.y - iprev_uv.y
                );
            }
        }
        else
        {
            composite_diffuse = vec3(0.0);
        }

        composite_diffuse = clamp(composite_diffuse, vec3(0.0), vec3(10.0));
    } else {
        vec3 dir = normalize(world_pos);
        vec2 polarCoord = project_skybox2uv(dir);

        if (biomeCategory != 16) {
            color.rgb = fromGamma(texelFetch(colortex0, iuv, 0).rgb) * 3.14;
            color.rgb = mix(color.rgb, sun_I * 10.0, smoothstep(0.9999, 0.99991, dot(normalize(view_pos), sunPosition * 0.01)));

            color.rgb += starField(dir * 2.0) * vec3(1.0, 0.6, 0.4);
            color.rgb += starField(dir) * vec3(0.7, 0.8, 1.3);
            color.rgb += starField(dir * 0.5);

#ifdef CLOUDS_2D
            vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);
            float mu_s = dot(dir, world_sun_dir);
            float mu = abs(mu_s);
            
            float c = cloud2d(dir * 512.0, cameraPosition);
            color.rgb = mix(color.rgb, color.rgb * (1.0 - c), smoothstep(0.1, 0.2, dir.y));

            float opmu2 = 1. + mu * mu;
            float phaseM = .1193662 * (1. - g2) * opmu2 / ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));
            color.rgb += (luma(sun_I + moon_I) * 0.2 + sun_I * phaseM * 0.2) * c;
#endif

            color.rgb = mix(color.rgb, moon_I * 8.0, smoothstep(0.9996, 0.99961, dot(normalize(view_pos), moonPosition * 0.01)));

            // color.rgb = vec3(color.a);
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
    gl_FragData[1] = vec4(composite_diffuse, view_pos.z);
}