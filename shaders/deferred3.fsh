#version 420 compatibility
#pragma optimize(on)

const bool colortex3Clear = false;

#define VECTORS
#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/sampling.glsl"
#include "libs/transform.glsl"
#include "libs/bsdf.glsl"
#include "libs/color.glsl"
#include "libs/noise.glsl"

float gaussian_weights[] = {
    0.071303, 0.131514, 0.189879, 0.214607, 0.189879, 0.131514, 0.071303
};

uniform float wetness;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec4 gbuffers = texelFetch(colortex4, iuv, 0);

    vec4 color = unpackUnorm4x8(gbuffers.g);
    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite = texelFetch(colortex0, iuv, 0).rgb;
    vec3 Ld_center = texelFetch(gaux2, iuv, 0).rgb;
    vec3 Ld = Ld_center * 0.214607;

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;
    vec4 specular = unpackUnorm4x8(gbuffers.a);

    if ((specular.a <= 0.05 || specular.a >= 0.995) && proj_pos.z < 0.99999) {
        const float bilateral_weight = 16.0;
        float total_weights = 0.214607;

        #pragma optionNV (unroll all)
        for (int i = 0; i < 7; i++) if (i != 3) {
            ivec2 uv_s = iuv + ivec2(0, i - 3);
            vec3 ld_s = texelFetch(gaux2, uv_s, 0).rgb;
            vec3 normal_s = normalDecode(texelFetch(colortex4, uv_s, 0).r);
            float weight_s = pow(max(0.0, dot(normal_s, normal)), 5.0) * gaussian_weights[i];
            weight_s *= exp(-norm2(ld_s, Ld_center) * bilateral_weight);

            Ld += ld_s * weight_s;
            total_weights += weight_s;
        }

        Ld /= total_weights;

        if (specular.g > 229.5 / 255.0)
        {
            color.rgb = vec3(1.0);
        }
        
        composite += color.rgb * Ld.rgb;
        // composite = Ld.rgb;

        // composite = normal * 0.5 + 0.5;
        // composite = vec3((specular.a <= 0.05 || specular.a >= 0.99));
        // composite = getF(specular.g, dot(-normalize(view_pos), normal));
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(composite, 1.0);
    gl_FragData[1] = vec4(composite, 1.0);
}