#version 420 compatibility
#pragma optimize(on)

#include "/libs/compat.glsl"

const bool colortex2Clear = false;

#define VECTORS
#define TRANSFORMATIONS_RESIDUAL

#include "libs/transform.glsl"

// #define TAA_NO_CLIP

vec3 sampleHistory(ivec2 iuv, vec3 min_bound, vec3 max_bound)
{
#ifdef TAA_NO_CLIP
    return texelFetch(colortex2, iuv, 0).rgb;
#else
    return clamp(texelFetch(colortex2, iuv, 0).rgb, min_bound, max_bound);
#endif
}

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);
    vec3 world_pos = view2world(proj2view(proj_pos));
    
    vec4 world_pos_prev = vec4(world_pos - previousCameraPosition + cameraPosition, 1.0);
    vec4 proj_pos_prev = gbufferPreviousProjection * (gbufferPreviousModelView * world_pos_prev);
    proj_pos_prev.xy /= proj_pos_prev.w;

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

    vec2 prev_uv = (proj_pos_prev.xy * 0.5 + 0.5);
    vec2 prev_uv_texels = prev_uv * vec2(viewWidth, viewHeight);
    vec2 iprev_uv = floor(prev_uv_texels);
    prev_uv += 0.5 * invWidthHeight;

    vec3 min_neighbor0 = min(current, min(min(min(current_n0, current_n1), min(current_n2, current_n3)), min(min(current_n4, current_n5), min(current_n6, current_n7))));
    vec3 max_neighbor0 = max(current, max(max(max(current_n0, current_n1), max(current_n2, current_n3)), max(max(current_n4, current_n5), max(current_n6, current_n7))));

    vec3 s00 = sampleHistory(ivec2(iprev_uv), min_neighbor0, max_neighbor0);
    vec3 s01 = sampleHistory(ivec2(iprev_uv) + ivec2(0, 1), min_neighbor0, max_neighbor0);
    vec3 s10 = sampleHistory(ivec2(iprev_uv) + ivec2(1, 0), min_neighbor0, max_neighbor0);
    vec3 s11 = sampleHistory(ivec2(iprev_uv) + ivec2(1, 1), min_neighbor0, max_neighbor0);

    vec3 history = mix(
        mix(s00, s10, prev_uv_texels.x - iprev_uv.x),
        mix(s01, s11, prev_uv_texels.x - iprev_uv.x),
        prev_uv_texels.y - iprev_uv.y
    );

    if (prev_uv.x < 0.0 || prev_uv.x > 1.0 || prev_uv.y < 0.0 || prev_uv.y > 1.0) history = current.rgb;

    vec3 color = mix(history, current.rgb, 0.1);

    if (depth <= 0.7) {
        color = current.rgb;
    }

/* DRAWBUFFERS:0 */
    gl_FragData[0] = vec4(color, 1.0);
}