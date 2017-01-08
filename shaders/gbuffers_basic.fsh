#version 130
#pragma optimize(on)

in lowp vec4 color;
flat in vec2 normal;

/* DRAWBUFFERS:024 */
void main() {
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(normal, 0.1, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
//	gl_FragData[3] = vec4(0.0, 0.0, 1.0, 1.0);
}
