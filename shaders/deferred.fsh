#version 420 compatibility
#pragma optimize(on)

#define BUFFERS

#include "libs/encoding.glsl"
#include "libs/transform.glsl"

float rand(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5f, a.y * .75f)) );
}

#define bayer4(a)   (bayer2( .5f*(a))*.25f+bayer2(a))
#define bayer8(a)   (bayer4( .5f*(a))*.25f+bayer2(a))
#define bayer16(a)  (bayer8( .5f*(a))*.25f+bayer2(a))
#define bayer32(a)  (bayer16(.5f*(a))*.25f+bayer2(a))
#define bayer64(a)  (bayer32(.5f*(a))*.25f+bayer2(a))

float getHorizonAngle(ivec2 iuv, vec2 offset, vec3 vpos, vec3 nvpos, out float l) {
    ivec2 ioffset = ivec2(offset * vec2(viewHeight, viewHeight));
    ivec2 suv = iuv + ioffset;

    if (suv.x < 0 || suv.y < 0 || suv.x > viewWidth || suv.y > viewHeight) return -1.0;

    float lod = 1;
    float depth_sample = texelFetch(depthtex0, suv, 0).r;

    vec3 proj_pos = getProjPos(suv, depth_sample);
    vec3 view_pos = proj2view(proj_pos);
    
    vec3 ws = view_pos - vpos;
    l = sqrt(dot(ws, ws));
    ws /= l;

    return dot(nvpos, ws);
}

uniform int frameCounter;
uniform float aspectRatio;

float getAO(ivec2 iuv, vec2 uv, vec3 vpos, vec3 vnorm) {
    float rand1 = (1.0 / 16.0) * float((((iuv.x + iuv.y) & 0x3) << 2) + (iuv.x & 0x3));
    float rand2 = (1.0 / 4.0) * float((iuv.y - iuv.x) & 0x3);
    
    float radius = 2.0 / -vpos.z * gbufferProjection[0][0];

    const float rotations[] = {60.0f, 300.0f, 180.0f, 240.0f, 120.0f, 0.0f};
    float rotation = rotations[frameCounter % 6] / 360.0f;
    float angle = (rand1 + rotation) * 3.1415926;

    const float offsets[] = { 0.0f, 0.5f, 0.25f, 0.75f };
    float offset = offsets[(frameCounter / 6 ) % 4];

    radius = clamp(radius, 0.01, 0.2);

    vec2 t = vec2(cos(angle), sin(angle));

    float theta1 = -1.0, theta2 = -1.0;

    vec3 wo_norm = -normalize(vpos);

    for (int i = 0; i < 4; i++) {
        float r = radius * (float(i) + fract(rand2 + offset) + 0.05) * 0.125;

        float l1;
        float h1 = getHorizonAngle(iuv, t * r * vec2(1.0, aspectRatio), vpos, wo_norm, l1);
        float theta1_p = mix(h1, theta1, clamp((l1 - 2) * 0.5, 0.0, 1.0));
        theta1 = theta1_p > theta1 ? theta1_p : mix(theta1_p, theta1, 0.7);
        float l2;
        float h2 = getHorizonAngle(iuv, -t * r * vec2(1.0, aspectRatio), vpos, wo_norm, l2);
        float theta2_p = mix(h2, theta2, clamp((l2 - 2) * 0.5, 0.0, 1.0));
        theta2 = theta2_p > theta2 ? theta2_p : mix(theta2_p, theta2, 0.7);
    }

    theta1 = -acos(theta1);
    theta2 = acos(theta2);
    
    vec3 bitangent	= normalize(cross(vec3(t, 0.0), wo_norm));
    vec3 tangent	= cross(wo_norm, bitangent);
    vec3 nx			= vnorm - bitangent * dot(vnorm, bitangent);

    float nnx		= length(nx);
    float invnnx	= 1.0 / (nnx + 1e-6);			// to avoid division with zero
    float cosxi		= dot(nx, tangent) * invnnx;	// xi = gamma + HALF_PI
    float gamma		= acos(cosxi) - 3.1415926 / 2.0;
    float cos_gamma	= dot(nx, wo_norm) * invnnx;
    float sin_gamma = -2.0 * cosxi;

    theta1 = gamma + max(theta1 - gamma, -3.1415926 / 2.0);
    theta2 = gamma + min(theta2 - gamma,  3.1415926 / 2.0);

    float alpha = 0.5 * cos_gamma + 0.5 * (theta1 + theta2) * sin_gamma - 0.25 * (cos(2.0 * theta1 - gamma) + cos(2.0 * theta2 - gamma));

    return nnx * alpha;
}

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = iuv * invWidthHeight;

    vec4 color = vec4(0.0);
    vec3 proj_pos = getProjPos(uv, color.r);

    vec3 normal = normalDecode(texelFetch(colortex4, iuv, 0).r);

    vec3 world_normal = mat3(gbufferModelViewInverse) * normal;

    if (proj_pos.z < 0.9999) {
        vec3 view_pos = proj2view(proj_pos);
        vec3 world_pos = view2world(view_pos);

        color.g = getAO(iuv, uv, view_pos, normal);
        color.r = linearizeDepth(color.r);
    }

/* DRAWBUFFERS:1 */
    gl_FragData[0] = color;
}