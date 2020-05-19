#version 420 compatibility
#pragma optimize(on)

const bool colortex2Clear = false;

#define VECTORS
#define TRANSFORMATIONS_RESIDUAL

#include "libs/transform.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 proj_pos = getProjPos(iuv);
    vec3 world_pos = view2world(proj2view(proj_pos));
    
    vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
    vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
    proj_pos_prev.xy /= proj_pos_prev.w;

    vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5) + 0.5 * invWidthHeight;
    vec4 history = texture(colortex2, prev_uv);
    if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) history = vec4(0.0);
    vec3 current = texelFetch(colortex0, iuv, 0).rgb;

    vec3 current_n0 = texelFetchOffset(colortex0, iuv, 0, ivec2(-1, -1)).rgb;
    vec3 current_n1 = texelFetchOffset(colortex0, iuv, 0, ivec2(-1,  0)).rgb;
    vec3 current_n2 = texelFetchOffset(colortex0, iuv, 0, ivec2(-1,  1)).rgb;
    vec3 current_n3 = texelFetchOffset(colortex0, iuv, 0, ivec2( 0, -1)).rgb;
    vec3 current_n4 = texelFetchOffset(colortex0, iuv, 0, ivec2( 0,  1)).rgb;
    vec3 current_n5 = texelFetchOffset(colortex0, iuv, 0, ivec2( 1, -1)).rgb;
    vec3 current_n6 = texelFetchOffset(colortex0, iuv, 0, ivec2( 1,  0)).rgb;
    vec3 current_n7 = texelFetchOffset(colortex0, iuv, 0, ivec2( 1,  1)).rgb;

    vec3 min_neighbor0 = min(current, min(min(min(current_n0, current_n1), min(current_n2, current_n3)), min(min(current_n4, current_n5), min(current_n6, current_n7))));
    vec3 max_neighbor0 = max(current, max(max(max(current_n0, current_n1), max(current_n2, current_n3)), max(max(current_n4, current_n5), max(current_n6, current_n7))));
    vec3 min_neighbor1 = min(current, min(min(current_n1, current_n3), min(current_n4, current_n6)));
    vec3 max_neighbor1 = max(current, max(max(current_n1, current_n3), max(current_n4, current_n6)));
    vec3 clamped_history = (clamp(history.rgb, min_neighbor0, max_neighbor0) + clamp(history.rgb, min_neighbor1, max_neighbor1)) * 0.5;

    vec3 color = mix(clamped_history, current.rgb, 0.05);

/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}