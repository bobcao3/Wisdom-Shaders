#version 130
#pragma optimize(on)

out lowp vec4 color;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;

	vec4 position = gl_ModelViewMatrix * gl_Vertex;
	gl_Position = gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
}
