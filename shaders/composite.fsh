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
//     ivec2 thread_id = ivec2(gl_FragCoord.st);
//     float jitter = bayer32(thread_id);
    
//     ivec3 iuv = ivec3((thread_id >> 3) << 3, (thread_id.y % 8) * 8 + (thread_id.x % 8));

//     iuv.xy += ivec2(WeylNth(int(jitter * 4096)) * 8.0); // Jitter on XY
    
//     vec3 view_pos = proj2view(getProjPos(iuv.xy, 1.0));
//     float depth = exp2(jitter + float(iuv.z) * 0.2);
//     view_pos *= depth / far;

//     vec3 wpos = view2world(view_pos);
//     vec3 in_scatter = vec3(0.0);
//     float extinction = 0.05;

//     float _s, _ds;
//     vec3 spos = shadowProjCascaded(world2shadowProj(wpos), _s, _ds);
//     float sun_visibility = 1.0;
//     if (spos != vec3(-1)) {
//         sun_visibility = step(spos.z, texelFetch(shadowtex1, ivec2(spos.xy * shadowMapResolution), 0).r);
//     }

//     in_scatter = vec3(sun_visibility);

// /* DRAWBUFFERS:5 */
//     gl_FragData[0] = vec4(in_scatter, extinction);
// }