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

uniform float wetness;

#define METAL_TINT

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);
    vec2 uv = vec2(iuv) * invWidthHeight;

    float depth = getDepth(iuv);
    vec3 proj_pos = getProjPos(iuv, depth);

    vec3 color;
    vec2 specular;
    decodeAlbedoSpecular(texelFetch(colortex4, iuv, 0).g, color, specular);
    
    specular.r = (1.0 - specular.r * specular.r);

    vec3 composite = texelFetch(colortex0, iuv, 0).rgb;
    vec3 Ld = texelFetch(gaux2, iuv, 0).rgb;

    if (proj_pos.z < 0.99999) {
#ifndef METAL_TINT
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
    }

/* DRAWBUFFERS:05 */
    gl_FragData[0] = vec4(composite, 1.0);
    gl_FragData[1] = vec4(composite, 1.0);
}