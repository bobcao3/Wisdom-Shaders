#version 130
#pragma optimize(on)

out lowp vec4 color;
flat out vec2 normal;

uniform mat4 gbufferModelViewInverse;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	gl_Position = ftransform();
	normal = normalEncode(mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal));
}
