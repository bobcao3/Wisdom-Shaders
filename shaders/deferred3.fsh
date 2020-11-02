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

#include "/libs/raytrace.glsl"
#include "/libs/atmosphere.glsl"

// #define REDUCE_GHOSTING

uniform int biomeCategory;

const bool colortex0MipmapEnabled = true;
const bool colortex3MipmapEnabled = true;
const bool colortex3Clear = false;

#define NUM_SSPT_RAYS 4 // [1 2 4 8 16 32]

vec3 sampleHistory(ivec2 iuv, float history_depth, vec3 Ld, float roughness)
{
    vec4 history_d = texelFetch(colortex3, iuv, 0);
            
    #ifdef REDUCE_GHOSTING
    float mix_weight = 0.15;
    #else
    float mix_weight = 0.07 + (1.0 - roughness) * 0.1;
    #endif

    float depth_difference = max(
        abs((history_d.a - history_depth) / history_depth),
        abs((history_d.a - history_depth) / history_d.a)
    );
    if (depth_difference > 0.05) {
        mix_weight = 1.0;
    }

    return mix(history_d.rgb, Ld, mix_weight);
}

flat in vec3 ambient_left;
flat in vec3 ambient_right;
flat in vec3 ambient_front;
flat in vec3 ambient_back;
flat in vec3 ambient_up;
flat in vec3 ambient_down;

#define AMBIENT_INTENSITY 0.5 // [0.25 0.5 0.75 1.0 1.25 1.5 1.75 2.0 2.25 2.5]

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st) * 2;
    vec2 uv = vec2(iuv) * invWidthHeight;

    if (uv.x > 1.0 || uv.y > 1.0) discard;

    float depth = sampleDepthLOD(iuv, 1);
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

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    vec3 view_pos = proj2view(proj_pos);
    vec3 V = normalize(-view_pos);
    vec3 world_pos = view2world(view_pos);

    float subsurface = decoded_b.b * 16.0;

    vec3 composite_diffuse = vec3(0.0);

    if (proj_pos.z < 0.99999) {
        vec3 F0 = getF0(color.rgb, specular.g);

        float emmisive = decoded_b.a;

        // SSPT
        if ((emmisive <= 0.05 || emmisive >= 0.995))
        {
            float lm_dist = (1.0 - lmcoord.y) * 4.0;
            float skyLight = max(0.0, 1.0 / (lm_dist * lm_dist + 1.0) - 0.0625);
            vec3 Ld = vec3(0.0);

            if (biomeCategory == 16)
            {
                skyLight = 0.25;
            }

            const float weight_per_ray = 1.0 / float(NUM_SSPT_RAYS);
            const float num_directions = 4096 * NUM_SSPT_RAYS;

            float stride = max(2.0, viewHeight / 640.0);
            float noise_sample = fract(texelFetch(colortex1, iuv & 0xFF, 0).r + texelFetch(colortex1, ivec2(frameCounter) & 0xFF, 0).r);

            int sky_lod = clamp(int((1.0 - specular.r + specular.g) * 3.0), 0, 3);

            vec3 mirror_dir = reflect(-V, normal);
            mat3 obj2view = make_coord_space(normal);

            float ao = 0.0;

            vec3 ambient =
              ( ambient_left  * max(0.0,  world_normal.x * 0.5 + 0.5)
              + ambient_right * max(0.0, -world_normal.x * 0.5 + 0.5)
              + ambient_front * max(0.0,  world_normal.z * 0.5 + 0.5)
              + ambient_back  * max(0.0, -world_normal.z * 0.5 + 0.5)
              + ambient_up    * max(0.0,  world_normal.y * 0.5 + 0.5)
              + ambient_down  * max(0.0, -world_normal.y * 0.5 + 0.5) );

            for (int i = 0; i < NUM_SSPT_RAYS; i++) {
                float noiseSeed = noise_sample * 65535 * NUM_SSPT_RAYS + i;
                vec2 grid_sample = WeylNth(int(noiseSeed));

                float pdf = 1.0;
                vec3 ray_trace_dir = ImportanceSampleGGX(grid_sample, normal, -V, specular.r, pdf);

                if (dot(ray_trace_dir, normal) < 0.05) continue;

                int lod = 3;
                float start_bias = clamp(0.1 / ray_trace_dir.z, 0.0, 1.0);
                ivec2 reflected = raytrace(view_pos, vec2(iuv), ray_trace_dir, stride, 1.45, subsurface > 0.5 ? 0.3 : 2.0, i, lod, specular.r > 0.8);
                
                vec3 diffuse = vec3(0.0);
                
                if (reflected != ivec2(-1) && depth > 0.7) {
                    lod = min(3, lod);
                    vec3 currDirect = texelFetch(colortex0, reflected >> lod, lod).rgb;
                    
                    vec4 lastComposite = texelFetch(colortex3, reflected >> (lod + 1), lod).rgba;

                    if (abs(lastComposite.a - view_pos.z) < 4.0) {
                        currDirect = (currDirect + lastComposite.rgb) * 0.5;
                    }

                    diffuse = currDirect;
                } else {
                    // vec3 world_dir = mat3(gbufferModelViewInverse) * ray_trace_dir;
                    // vec3 skyRadiance = skyLight * texture(gaux4, project_skybox2uv(world_dir), sky_lod).rgb;

                    // diffuse = min(skyRadiance, vec3(1.0));

                    diffuse = ambient * AMBIENT_INTENSITY * skyLight;
                }

                Ld += diffuse * clamp(getF(specular.g, dot(V, normal)), vec3(0.0), vec3(1.0));
            }

            Ld *= weight_per_ray;

            vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
            vec4 view_pos_prev = gbufferPreviousModelView * world_pos_prev;
            vec4 proj_pos_prev = gbufferPreviousProjection * view_pos_prev;
            proj_pos_prev.xyz /= proj_pos_prev.w;

            vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5) * 0.5;

            if (depth < 0.7)
            {
                prev_uv = uv;
            }

            vec2 prev_uv_texels = prev_uv * vec2(viewWidth, viewHeight);
            vec2 iprev_uv = floor(prev_uv_texels);
            prev_uv += 0.5 * invWidthHeight;

            if (prev_uv.x <= 0.001 || prev_uv.x >= 0.5 || prev_uv.y <= 0.001 || prev_uv.y >= 0.5)
            {
                composite_diffuse = Ld;
            }
            else
            {
                float history_depth = view_pos_prev.z;
                
                vec3 s00 = sampleHistory(ivec2(iprev_uv), history_depth, Ld, specular.r);
                vec3 s01 = sampleHistory(ivec2(iprev_uv) + ivec2(0, 1), history_depth, Ld, specular.r);
                vec3 s10 = sampleHistory(ivec2(iprev_uv) + ivec2(1, 0), history_depth, Ld, specular.r);
                vec3 s11 = sampleHistory(ivec2(iprev_uv) + ivec2(1, 1), history_depth, Ld, specular.r);

                composite_diffuse = mix(
                    mix(s00, s10, prev_uv_texels.x - iprev_uv.x),
                    mix(s01, s11, prev_uv_texels.x - iprev_uv.x),
                    prev_uv_texels.y - iprev_uv.y
                );
            }
        }

        composite_diffuse = clamp(composite_diffuse, vec3(0.0), vec3(10.0));
    }

/* DRAWBUFFERS:3 */
    gl_FragData[0] = vec4(composite_diffuse, view_pos.z);
}