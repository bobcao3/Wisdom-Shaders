#include "/libs/compat.glsl"

const bool colortex3Clear = false;

#define VECTORS
#define BUFFERS

#include "/libs/uniforms.glsl"
#include "/libs/encoding.glsl"
#include "/libs/sampling.glsl"
#include "/libs/transform.glsl"
#include "/libs/bsdf.glsl"
#include "/libs/color.glsl"
#include "/libs/noise.glsl"

float weights[3] = { 0.5, 1.0, 0.5 };

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float depth = getDepth(iuv);

    vec3 normal = normalDecode(texelFetch(colortex4, iuv, 0).r);
    
    vec3 center_color = texelFetch(SRC_TEXTURE, iuv, 0).rgb;
    vec3 composite = vec3(0.0);

    const float bilateral_weight = 2.0;

    if (depth < 1.0) {
        float total_weights = 0.000316;
        
        #pragma optionNV (unroll all)
        for (int i = 0; i < 3; i++) {
            #pragma optionNV (unroll all)
            for (int j = 0; j < 3; j++) {
                ivec2 uv_s = iuv + ivec2(i - 1, j - 1) * STRIDE;
                vec3 ld_s = texelFetch(SRC_TEXTURE, uv_s, 0).rgb;
                vec3 normal_s = normalDecode(texelFetch(colortex4, uv_s, 0).r);
                float weight_s = pow5(max(0.0, dot(normal_s, normal))) * weights[i] * weights[j];
                weight_s *= exp(-norm2(ld_s, center_color) * bilateral_weight);

                composite += ld_s * weight_s;
                total_weights += weight_s;
            }
        }

        composite /= total_weights;
    }

    gl_FragData[0] = vec4(composite, 1.0);
}