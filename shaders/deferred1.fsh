#version 420 compatibility
#pragma optimize(on)

#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/bsdf.glsl"
#include "libs/transform.glsl"
#include "libs/color.glsl"

#define VECTORS
#define CLIPPING_PLANE
#include "libs/uniforms.glsl"

uniform float rainStrength;

flat in vec3 sun_I;

#include "libs/raytrace.glsl"

#define PCSS

uniform int biomeCategory;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    float subsurface = decoded_b.b * 16.0;

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    vec4 specular = unpackUnorm4x8(gbuffers.a);
    specular.r = 1.0 - specular.r;

    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);

    if (proj_pos.z < 0.9999) {
        
        vec3 sun_vec = shadowLightPosition * 0.01;
        float shadow;
        vec3 L = vec3(0.0);

        if (biomeCategory != 16) {
            //int cascade = int(clamp(floor(log2(max(abs(world_pos.x), abs(world_pos.z)) / 8.0)), 0.0, 4.0));
            float scale;
            vec3 shadow_proj_pos = world2shadowProj(world_pos + world_normal * 0.05);

            float shadow_sampled_depth;
#ifdef PCSS
            float shadow_radius = getShadowRadiusPCSS(shadowtex1, shadow_proj_pos, shadow_sampled_depth, iuv);
#else
            const float shadow_radius = 0.001;
#endif
            float shadow = shadowFiltered(shadowtex1, shadow_proj_pos, shadow_sampled_depth, shadow_radius, iuv);

            vec3 b = normalize(cross(sun_vec, normal));
            vec3 t = cross(normal, b);

            if (depth > 0.7) {
                int lod = 0;
                float rt_contact_shadow = float(raytrace(view_pos, vec2(iuv), sun_vec, false, 4.0, 1.0, 0.04, 0, lod) != ivec2(-1));
                rt_contact_shadow *= smoothstep(0.20, 0.35, abs(dot(sun_vec, normal)));

                shadow = min(shadow, 1.0 - rt_contact_shadow);
            }
            
            vec3 spos_diff = vec3(shadow_proj_pos.xy, max(shadow_proj_pos.z - shadow_sampled_depth, 0.0));
            float subsurface_depth = 1.0 - smoothstep(0.0, subsurface + pow(max(0.0, dot(normalize(view_pos), sun_vec)), 8.0), sposLinear(spos_diff) * 32.0);

            float G = oren_nayer(V, sun_vec, normal, specular.r, dot(normal, sun_vec), dot(normal, V));

            if (subsurface > 0.0) {
                shadow = mix(min(subsurface_depth, 1.0), shadow * G, min(1.0, subsurface));
            } else {
                shadow = shadow * G;
            }

            L = max(vec3(0.0), sun_I * shadow);

            color.a = shadow;
        }

        vec3 kD = pbr_get_kD(color.rgb, specular.g);

        const vec3 torch1900K = pow(vec3(255.0, 147.0, 41.0) / 255.0, vec3(2.2)) * 1.0;
        const vec3 torch5500K = vec3(1.2311, 1.0, 0.8286) * 0.6;
        const vec3 torch_warm = vec3(1.2311, 0.7, 0.4286) * 0.8;

        float blockLight = pow(lmcoord.x, 4.0);
        vec3 block_L = torch1900K * blockLight * kD; // 10000 lux

        float emmisive = decoded_b.a;
        if (emmisive <= (254.5 / 255.0) && emmisive > 0.05) {
            color.rgb *= emmisive * 3.0; // Max at 30000 lux
        } else {
            color.rgb = clamp(diffuse_specular_brdf(V, sun_vec, normal, color.rgb, specular.r, specular.g) * L + color.rgb * block_L, vec3(0.0), vec3(100.0));
        }
    } else {
        if (biomeCategory != 16) {
            color.rgb = fromGamma(texelFetch(colortex0, iuv, 0).rgb) * 3.14;
        }

        vec3 dir = normalize(world_pos);
        color.rgb += texture(gaux4, project_skybox2uv(dir)).rgb;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = color;
}