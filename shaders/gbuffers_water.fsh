#version 130
#pragma optimize(on)

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform float frameTimeCounter;
uniform vec3 cameraPosition;

//flat in vec2 normal;
in vec3 wpos;
flat in lowp float iswater;
in vec2 texcoord;
flat in vec2 normal;

#define PBR

/* DRAWBUFFERS:0346 */
void main() {
	if (iswater < 0.90f) {
		gl_FragData[0] = vec4(0.2, 0.2, 0.4, 0.18);

		#ifdef PBR
		gl_FragData[2] = vec4(0.05, 0.99, 0.0, 1.0);
		#else
		gl_FragData[2] = vec4(0.8, 0.0, 0.0, 1.0);
		#endif
	}	else {
		gl_FragData[0] = texture2D(texture, texcoord);

		#ifdef PBR
		gl_FragData[2] = vec4(0.01, 0.99, 0.0, 1.0);
		#else
		gl_FragData[2] = vec4(0.8, 0.0, 0.0, 1.0);
		#endif
	}
	gl_FragData[1] = vec4(normal, iswater, 1.0);

	gl_FragData[3] = vec4(wpos, 1.0);
}
