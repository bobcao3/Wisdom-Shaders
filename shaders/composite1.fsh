#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;

const bool colortex2Clear = false;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec4 color = texelFetch(colortex0, iuv, 0);

/* DRAWBUFFERS:2 */
    gl_FragData[0] = color;
}