#version 130
#pragma optimize(on)

uniform sampler2D texture;

in lowp vec4 color;
flat in vec2 normal;
in highp vec2 texcoord;

/* DRAWBUFFERS:024 */
void main() {
	gl_FragData[0] = texture2D(texture, texcoord) * color;
	gl_FragData[1] = vec4(normal, 0.2, 1.0);
	gl_FragData[2] = vec4(0.0, 0.0, 0.0, 1.0);
	//gl_FragData[3] = vec4(0.5, 0.0, 1.0, 1.0);
}
