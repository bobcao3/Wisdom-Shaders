#version 130
#pragma optimize(on)

uniform sampler2D texture;

in vec2 texcoord;
in vec4 color;

void main() {
	vec4 c = texture2D(texture, texcoord) * color;
	gl_FragData[0] = c;
}
