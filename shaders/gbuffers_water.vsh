#version 130
#pragma optimize(on)

attribute vec4 mc_Entity;

uniform sampler2D noisetex;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform vec3 cameraPosition;
uniform float frameTimeCounter;

const float PI = 3.14159f;

out vec3 wpos;
//flat out vec2 normal;
flat out lowp float iswater;
out vec2 texcoord;

#include "gbuffers.inc.vsh"

VSH {
	vec4 position;
	if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) {
		iswater = 0.78f;
		position = gl_ModelViewMatrix * (gl_Vertex - vec4(0.0, 0.1, 0.0, 0.0));
	}	else {
		iswater = 0.95f;
		position = gl_ModelViewMatrix * gl_Vertex;
		//normal = gl_Normal;
	}
	wpos = position.xyz;
	//normal = normalEncode(normalize(gl_Normal));
	gl_Position = gl_ProjectionMatrix * position;
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}
