#version 130
#pragma optimize(on)

in vec3 color;

/* DRAWBUFFERS:02 */
void main() {
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(0.0);
}
