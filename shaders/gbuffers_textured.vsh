#version 130
#pragma optimize(on)

out lowp vec4 color;
flat out vec2 normal;
out highp vec2 texcoord;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	gl_Position = ftransform();
	normal = normalEncode(normalize(gl_Normal));
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}
