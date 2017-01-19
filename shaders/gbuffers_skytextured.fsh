#version 130
#pragma optimize(on)

/* DRAWBUFFERS:02 */
void main() {
	gl_FragData[0] = vec4(0.8, 0.9, 0.9, 1.0);
	gl_FragData[1] = vec4(0.0);
}
