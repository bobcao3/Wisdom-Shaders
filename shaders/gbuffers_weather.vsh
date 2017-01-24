#version 130
#pragma optimize(on)

uniform mat4 gbufferModelViewInverse;

out lowp vec4 color;
flat out vec2 normal;
out highp vec2 texcoord;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	gl_Position = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	normal = normalEncode(gl_NormalMatrix * vec3(0.0, 1.0, 0.0));
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}
