#version 130
#pragma optimize(on)

out vec2 texcoord;
out float centerDepth;

uniform sampler2D depthtex0;

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.st;

	centerDepth = min(0.9995, texture(depthtex0, vec2(0.5, 0.5)).r);
}
