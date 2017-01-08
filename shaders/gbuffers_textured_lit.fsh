#version 130
#pragma optimize(on)

uniform sampler2D texture;

in lowp vec4 color;
flat in vec2 normal;
in highp vec2 texcoord;
in highp vec3 wpos;
in lowp vec2 lmcoord;

/* DRAWBUFFERS:01245 */
void main() {
	gl_FragData[0] = texture2D(texture, texcoord) * color;
	gl_FragData[1] = vec4(wpos, 1.0);
	gl_FragData[2] = vec4(normal, 0.38, 1.0);
	gl_FragData[3] = vec4(0.0, 0.0, 0.0, 1.0);
	gl_FragData[4] = vec4(lmcoord, 1.0, 1.0);
}
