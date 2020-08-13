#version 420 compatibility
#pragma optimize(on)

flat out float exposure;

uniform sampler2D colortex2;
uniform vec2 invWidthHeight;

#include "libs/taa.glsl"

void main() {
    float L = 0.0;

    for (int i = 0; i < 8; i++) {
        vec2 loc = WeylNth(i) * 8 * invWidthHeight;
        L += texture(colortex2, loc).a;
    }

    exposure = clamp(6.0 / L, 0.1, 15.0);

    gl_Position = ftransform();
}
