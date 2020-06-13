// #version 420 compatibility
// #pragma optimize(on)

// #define BUFFERS

// #include "libs/encoding.glsl"
// #include "libs/sampling.glsl"
// #include "libs/bsdf.glsl"
// #include "libs/transform.glsl"
// #include "libs/color.glsl"
// #include "configs.glsl"

// #define VECTORS
// #define CLIPPING_PLANE
// #include "libs/uniforms.glsl"

// uniform float rainStrength;
// const bool colortex0MipmapEnabled = true;

// #include "libs/raytrace.glsl"

// uniform vec3 fogColor;
// uniform int biomeCategory;

// void main() {
//     ivec2 iuv = ivec2(gl_FragCoord.st);
//     float jitter = bayer32(iuv);
    
//     vec3 view_pos = proj2view(getProjPos(iuv.xy));
//     vec3 wpos = view2world(view_pos);

//     vec4 color = vec4(0.0);

//     for (int i = 0; i < 16; i++) {
//         vec3 sample_view_pos = view_pos * ((i + jitter) / 16.0);
//         ivec3 sample_iuv = ivec3((iuv >> 3) << 3, int(log2(sample_view_pos.z) * 5.0));
//         ivec2 iuv = sample_iuv.xy + ivec2(sample_iuv.z / 8, sample_iuv.z % 7);

//         vec4 froxel_sample = texelFetch(gaux2, iuv, 0);
//         color.rgb += froxel_sample.rgb / 16.0;
//     }

// /* DRAWBUFFERS:0 */
//     gl_FragData[0] = color;
// }