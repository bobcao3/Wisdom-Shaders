#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

const bool colortex3Clear = false;

#define VECTORS
#define BUFFERS

#include "/libs/encoding.glsl"
#include "/libs/sampling.glsl"
#include "/libs/transform.glsl"
#include "/libs/bsdf.glsl"
#include "/libs/color.glsl"
#include "/libs/noise.glsl"

float gaussian_weights[] = {
    0.071303, 0.131514, 0.189879, 0.214607, 0.189879, 0.131514, 0.071303
};

uniform float wetness;

// #define METAL_TINT

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    uvec3 gbuffers = texelFetch(colortex4, iuv, 0).rgb;

    vec3 color;
    vec2 specular;
    decodeAlbedoSpecular(gbuffers.g, color, specular);
    
    specular.r = (1.0 - specular.r * specular.r);

    vec3 normal = normalDecode(gbuffers.r);

    vec3 composite = texelFetch(colortex0, iuv, 0).rgb;
    vec3 Ld_center = texelFetch(gaux2, iuv, 0).rgb;
    vec3 Ld = Ld_center * 0.214607;

    vec4 decoded_b = unpackUnorm4x8(gbuffers.b);
    vec2 lmcoord = decoded_b.st;\
    float emmisive = decoded_b.a;

    if ((emmisive <= 0.05 || emmisive >= 0.995) && proj_pos.z < 0.99999) {
        const float bilateral_weight = 2.0;
        float total_weights = 0.214607;

        #pragma optionNV (unroll all)
        for (int i = 0; i < 7; i++) {
            ivec2 uv_s = iuv + ivec2(0, i - 3);
            vec3 ld_s = texelFetch(gaux2, uv_s, 0).rgb;
            vec3 normal_s = normalDecode(texelFetch(colortex4, uv_s, 0).r);
            float weight_s = pow(max(0.0, dot(normal_s, normal)), 5.0) * gaussian_weights[i];
            weight_s *= exp(-norm2(ld_s, Ld_center) * bilateral_weight);

            Ld += ld_s * weight_s;
            total_weights += weight_s;
        }

        Ld /= total_weights;

#ifdef METAL_TINT
        if (specular.g > 229.5 / 255.0)
        {
            color.rgb = vec3(1.0);
        }
#else
        if (specular.g > 229.5 / 255.0)
        {
            color.rgb = color.rgb * 0.5 + 0.5;
        }
#endif
        
        composite += color.rgb * Ld.rgb;
        // composite = Ld.rgb;

        // composite = vec3(normal * 0.5 + 0.5);
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(composite, 1.0);
    gl_FragData[1] = vec4(composite, 1.0);
}