#version 420 compatibility
#pragma optimize(on)

flat out float exposure;

uniform sampler2D colortex2;
uniform vec2 invWidthHeight;

#include "/libs/taa.glsl"

uniform float screenBrightness;

void main() {
    float L = 0.0;

    for (int i = 0; i < 8; i++) {
        vec2 loc = WeylNth(i) * 8 * invWidthHeight;
        L += texture(colortex2, loc).a;
    }

    exposure = clamp(4.0 / L, 0.1, 10.0) * (screenBrightness * 2.0 + 0.5);

    gl_Position = ftransform();
}
