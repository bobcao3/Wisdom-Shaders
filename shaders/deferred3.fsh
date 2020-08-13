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

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float depth = getDepth(iuv);

    vec3 normal = normalDecode(texelFetch(colortex4, iuv, 0).r);
    
    vec3 center_color = texelFetch(colortex3, iuv, 0).rgb;
    vec3 composite = center_color * 0.214607;
    float total_weights = 0.214607;

    const float bilateral_weight = 16.0;

    if (depth < 1.0) {
        #pragma optionNV (unroll all)
        for (int i = 0; i < 7; i++) if (i != 3) {
            ivec2 uv_s = iuv + ivec2(i - 3, 0);
            vec3 ld_s = texelFetch(colortex3, uv_s, 0).rgb;
            vec3 normal_s = normalDecode(texelFetch(colortex4, uv_s, 0).r);
            float weight_s = pow(max(0.0, dot(normal_s, normal)), 5.0) * gaussian_weights[i];
            weight_s *= exp(-norm2(ld_s, center_color) * bilateral_weight);

            composite += ld_s * weight_s;
            total_weights += weight_s;
        }

        composite /= total_weights;
    }

/* DRAWBUFFERS:5 */
    gl_FragData[0] = vec4(composite, 1.0);
}