#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;

uniform sampler2D shadowtex0;

#include "configs.glsl"

uniform float viewWidth;
uniform float viewHeight;

#include "libs/color.glsl"

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex0, iuv, 0);
    if (iuv.x < shadowMapQuadRes / 2 && iuv.y < shadowMapQuadRes / 2) {
        color = texelFetch(shadowtex0, iuv * 4, 0);
    }

    float exposure = 0.5;

    color = toGamma(color * exposure);
    color.rgb = ACESFitted(color.rgb) * 1.4;

    gl_FragColor = clamp(color, 0.0, 1.0);
}