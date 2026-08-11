#version 120

varying vec4 color;

void main() {
	color = gl_Color;
	gl_Position = ftransform();
}
