#version 130
#pragma optimize(on)

#include "gbuffers.inc.vsh"

out vec3 color;

VSH {
	color = gl_Color.rgb * gl_Color.a;
	gl_Position = ftransform();
}
