#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

const bool colortex2Clear = false;

#define VECTORS
#define TRANSFORMATIONS_RESIDUAL

#include "libs/transform.glsl"

// #define TAA_NO_CLIP

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);
    vec3 world_pos = view2world(proj2view(proj_pos));
    
    vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
    vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
    proj_pos_prev.xy /= proj_pos_prev.w;

    vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5) + 0.5 * invWidthHeight;
    vec4 history = texture(colortex2, prev_uv);
    if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) history = vec4(0.0);
    vec3 current = texelFetch(colortex0, iuv, 0).rgb;

    if (isnan(current.r) || isnan(current.g) || isnan(current.b)) current = vec3(0.0);

    vec3 current_n0 = texelFetchOffset(colortex0, iuv, 0, ivec2(-1, -1)).rgb;
    vec3 current_n1 = texelFetchOffset(colortex0, iuv, 0, ivec2(-1,  0)).rgb;
    vec3 current_n2 = texelFetchOffset(colortex0, iuv, 0, ivec2(-1,  1)).rgb;
    vec3 current_n3 = texelFetchOffset(colortex0, iuv, 0, ivec2( 0, -1)).rgb;
    vec3 current_n4 = texelFetchOffset(colortex0, iuv, 0, ivec2( 0,  1)).rgb;
    vec3 current_n5 = texelFetchOffset(colortex0, iuv, 0, ivec2( 1, -1)).rgb;
    vec3 current_n6 = texelFetchOffset(colortex0, iuv, 0, ivec2( 1,  0)).rgb;
    vec3 current_n7 = texelFetchOffset(colortex0, iuv, 0, ivec2( 1,  1)).rgb;

#ifdef TAA_NO_CLIP
    vec3 clamped_history = history.rgb;
#else
    vec3 min_neighbor0 = min(current, min(min(min(current_n0, current_n1), min(current_n2, current_n3)), min(min(current_n4, current_n5), min(current_n6, current_n7))));
    vec3 max_neighbor0 = max(current, max(max(max(current_n0, current_n1), max(current_n2, current_n3)), max(max(current_n4, current_n5), max(current_n6, current_n7))));
    vec3 clamped_history = clamp(history.rgb, min_neighbor0, max_neighbor0);
#endif

    vec3 color = mix(clamped_history, current.rgb, 0.07);

    if (depth <= 0.7) {
        color = current.rgb;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}