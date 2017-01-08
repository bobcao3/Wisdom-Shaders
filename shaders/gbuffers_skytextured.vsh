#version 130
#pragma optimize(on)

out vec4 color;
out highp vec2 texcoord;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
}
