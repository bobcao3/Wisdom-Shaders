#version 130
#pragma optimize(on)

uniform sampler2D texture;

in lowp vec4 color;
flat in vec2 normal;
in highp vec2 texcoord;

/* DRAWBUFFERS:02 */
void main() {
	gl_FragData[0] = texture2D(texture, texcoord) * color;
	gl_FragData[1] = vec4(normal, 0.38, 1.0);
}
