#version 420 compatibility
#pragma optimize(on)

uniform sampler2D depthtex0;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

/* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(texelFetch(depthtex0, iuv, 0).r, 1.0, 0.0, 0.0);
}