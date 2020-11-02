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
#define CLOUD_SHADOW

uniform int biomeCategory;
uniform int heldBlockLightValue;
uniform int heldBlockLightValue2;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec3 gbuffers = texelFetch(colortex4, iuv, 0).rgb;

    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    vec2 specular;
    decodeAlbedoSpecular(gbuffers.g, color.rgb, specular);
    
    specular.r = (1.0 - specular.r);
    specular.g = clamp(specular.g, 0.01, 0.99);
    
    vec3 normal = normalDecode(gbuffers.r);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    float subsurface = decoded_b.b * 16.0;

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);

    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (sunPosition * 0.01);

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
            float subsurface_depth = 1.0 - smoothstep(0.0, subsurface + pow8(max(0.0, dot(normalize(view_pos), sun_vec))), sposLinear(spos_diff) * 32.0);

            if (subsurface > 0.0) {
                shadow = mix(min(subsurface_depth, 1.0), shadow, min(1.0, subsurface));
            } else {
                shadow = shadow;
            }

#ifdef CLOUD_SHADOW
            float trans = scatterTransmittance(vec3(0.0, cameraPosition.y, 0.0), world_sun_dir, world_sun_dir, Ra, 0.0, cameraPosition + world_pos * 8.0);
            shadow *= smoothstep(trans, 0.0, 0.7);
#endif

            L = max(vec3(0.0), (sun_I + moon_I) * shadow);
            L = brdf_ggx_oren_schlick(color.rgb, L, specular.r, specular.g, subsurface, F0, sun_vec, normal, V);

            // L = vec3(abs(dot(normal, L)));

            color.a = shadow;
        }

        const vec3 torch1900K = pow(vec3(255.0, 147.0, 41.0) / 255.0, vec3(2.2));
        const vec3 torch3500K = pow(vec3(255.0, 196.0, 137.0) / 255.0, vec3(2.2));
        const vec3 torch5500K = pow(vec3(255.0, 236.0, 224.0) / 255.0, vec3(2.2));

        #define BLOCKLIGHT_R 1.0 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
        #define BLOCKLIGHT_G 0.29 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
        #define BLOCKLIGHT_B 0.02 // [0.0 0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.70 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
        #define EMMISIVE_BRIGHTNESS 1.2 // [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0 4.1 4.2 4.3 4.4 4.5 4.6 4.7 4.8 4.9 5.0]

        vec3 blockLightColor = vec3(BLOCKLIGHT_R, BLOCKLIGHT_G, BLOCKLIGHT_B);

        float lm_dist = (1.0 - min(1.0, lmcoord.x / 0.9)) * 16.0;
        float blockLight = max(0.0, 1.0 / (lm_dist * lm_dist + 1.0) - 0.004);
        vec3 block_L = blockLightColor * blockLight; // 10000 lux

        float view_distance = length(view_pos);
        vec3 hand_L = blockLightColor * (float(max(heldBlockLightValue, heldBlockLightValue2)) / 12.0 / ((view_distance + 1.0) * (view_distance + 1.0)));

        float emmisive = decoded_b.a;
        if (emmisive <= (254.5 / 255.0) && emmisive > 0.05) {
            color.rgb = pow(color.rgb, vec3(1.3)) * emmisive * EMMISIVE_BRIGHTNESS; // Max at 10000 lux
        } else {
            color.rgb = L
             + diffuse_brdf_ggx_oren_schlick(color.rgb, block_L, specular.r, specular.g, F0, normal, V)
             + brdf_ggx_oren_schlick(color.rgb, hand_L, specular.r, specular.g, subsurface, F0, V, normal, V);
        }
    } else {
        vec3 dir = normalize(world_pos);
        vec2 polarCoord = project_skybox2uv(dir);

        if (biomeCategory != 16) {
            color.rgb = fromGamma(texelFetch(colortex0, iuv, 0).rgb) * 3.14;
            color.rgb = mix(color.rgb, sun_I * 10.0, smoothstep(0.9999, 1.0, dot(normalize(view_pos), sunPosition * 0.01)));
            color.rgb = mix(color.rgb, moon_I * 8.0, smoothstep(0.9996, 0.99971, dot(normalize(view_pos), moonPosition * 0.01)));

            color.rgb += starField(dir * 2.0) * vec3(1.0, 0.6, 0.4);
            color.rgb += starField(dir) * vec3(0.7, 0.8, 1.3);
            color.rgb += starField(dir * 0.5);

#ifdef CLOUDS_2D
            float mu_s = dot(dir, world_sun_dir);
            float mu = abs(mu_s);
            
            float c = cloud2d(dir * 512.0, cameraPosition);
            color.rgb = mix(color.rgb, color.rgb * (1.0 - c), smoothstep(0.1, 0.2, dir.y));

            float opmu2 = 1. + mu * mu;
            float phaseM = .1193662 * (1. - g2) * opmu2 / ((2. + g2) * pow1d5(1. + g2 - 2.*g*mu));
            color.rgb += (luma(sun_I + moon_I) * 0.2 + sun_I * phaseM * 0.2) * c;
#endif
        }

#ifdef CLOUDS
        vec4 atmosphere = bicubicSample(gaux4, vec2(iuv) * invWidthHeight * vec2(0.5, 0.5) + vec2(0.5, 0.0));
        color.rgb *= atmosphere.a;
        color.rgb += atmosphere.rgb;
#else
        color.rgb += bicubicSample(gaux4, polarCoord).rgb;
#endif
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}