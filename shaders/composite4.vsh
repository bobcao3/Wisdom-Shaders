#version 130
#pragma optimize(on)

uniform int worldTime;

out vec2 texcoord;

void main() {
	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0.st;
}
