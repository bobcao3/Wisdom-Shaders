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

vec3 get_uniform_hemisphere_weighted(vec2 r) {
    float phi = 2.0 * 3.1415926 * r.y;
    float sqrt_rx = sqrt(r.x);

    return vec3(cos(phi) * sqrt_rx, sin(phi) * sqrt_rx, sqrt(1.0 - r.x));
}

mat3 make_coord_space(vec3 n) {
    vec3 h = n;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
        h.x = 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
        h.y = 1.0;
    else
        h.z = 1.0;

    vec3 y = normalize(cross(h, n));
    vec3 x = normalize(cross(n, y));

    return mat3(x, y, n);
}

#include "libs/raytrace.glsl"

const bool colortex1Clear = false;
const bool colortex3Clear = false;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite_diffuse = vec3(0.0);
    vec3 composite_specular = vec3(0.0);

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;

    vec4 specular = unpackUnorm4x8(gbuffers.a);
    specular.r = 1.0 - specular.r;
    
    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);
    
    if (proj_pos.z < 0.9999) {
        float ao = 0.0;

        float sunDotUp = dot(normalize(sunPosition), normalize(upPosition));
        float ambientIntensity = (max(sunDotUp, 0.0) + max(-sunDotUp, 0.0) * 0.01);

        float skyLight = smoothstep(0.04, 1.0, lmcoord.y);
        vec3 Ld = vec3(0.0);
        vec3 Ld_sky = vec3(0.0);
        vec3 Ls = vec3(0.0);

        //vec3 ray_trace_dir = reflect(normalize(view_pos), normal);
        const int num_sspt_rays = 6;
        const float weight_per_ray = 1.0 / float(num_sspt_rays);
        const float num_directions = 4096 * num_sspt_rays;

        float stride = max(1.0, viewHeight / 1080.0);
        float noise_sample = fract(bayer64(iuv));

        int sky_lod = clamp(int((1.0 - specular.r + specular.g) * 3.0), 0, 3);

        for (int i = 0; i < num_sspt_rays; i++) {
            vec2 grid_sample = WeylNth(int(noise_sample * num_directions + (frameCounter & 0xFF) * num_directions + i));
            grid_sample.x *= 0.8;
            vec3 object_space_sample = get_uniform_hemisphere_weighted(grid_sample);
            vec3 ray_trace_dir = make_coord_space(normal) * object_space_sample;
            vec3 mirror_dir = reflect(normalize(view_pos), normal);

            float coin_flip = fract(noise_sample + hash(iuv + i));
            ray_trace_dir = grid_sample.y < pow((1.0 - specular.r + specular.g) * 0.5, 5.0) ? mirror_dir : ray_trace_dir;

            int lod;
            float start_bias = clamp(1.0 / ray_trace_dir.z, 0.0, 10.0) * 0.1;
            ivec2 reflected = raytrace(view_pos + ray_trace_dir * start_bias, vec2(iuv), ray_trace_dir, false, stride, 1.5, 0.5, i, lod);
            if (reflected != ivec2(-1)) {
                vec3 radiance = texelFetch(colortex0, reflected >> lod, lod).rgb;

                radiance *= 1.0 / object_space_sample.z;
                vec3 kD;
                vec3 brdf = pbr_brdf(V, ray_trace_dir, normal, color.rgb, specular.r, specular.g, kD);
                float oren = oren_nayer(V, ray_trace_dir, normal, specular.r, object_space_sample.z, abs(dot(normal, V)));
                Ld += radiance * kD * oren;
                Ls += radiance * brdf * oren;
            } else {
                vec3 world_dir = mat3(gbufferModelViewInverse) * ray_trace_dir;
                float sun_disc_occulusion = smoothstep(abs(dot(ray_trace_dir, sunPosition * 0.01)), 0.99, 0.999);
                Ld += skyLight * texture(gaux4, project_skybox2uv(world_dir), sky_lod).rgb * sun_disc_occulusion;
            }
        }
        
        ao = ao * weight_per_ray;
        Ld *= weight_per_ray;
        Ls *= weight_per_ray;
        
        vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
        vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
        proj_pos_prev.xyz /= proj_pos_prev.w;

        vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5) + 0.5 * invWidthHeight;
        vec4 history_d = texture(colortex3, prev_uv);
        vec4 history_s = texture(colortex1, prev_uv);
        
        float mix_weight = 0.05;
        if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) {
            mix_weight = 1.0;
        }

        float history_depth = proj_pos_prev.z * 0.5 + 0.5;
        float depth_difference = abs(history_d.a - history_depth) / history_depth;
        if (depth_difference > 0.001) {
            mix_weight = 1.0;
        }

        composite_diffuse = clamp(mix(history_d.rgb, Ld, mix_weight), vec3(0.0), vec3(100.0));
        composite_specular = clamp(mix(history_s.rgb, Ls, 0.1 + 0.9 * mix_weight), vec3(0.0), vec3(100.0));
    } else {
        vec3 dir = normalize(world_pos);
        composite_diffuse = texture(gaux4, project_skybox2uv(dir)).rgb;
    }

/* DRAWBUFFERS:13 */
    gl_FragData[0] = vec4(composite_specular, 1.0);
    gl_FragData[1] = vec4(composite_diffuse, depth);
}