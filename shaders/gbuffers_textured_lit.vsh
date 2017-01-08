#version 130
#pragma optimize(on)

uniform mat4 gbufferModelViewInverse;

out lowp vec4 color;
flat out vec2 normal;
out highp vec2 texcoord;
out highp vec3 wpos;
out lowp vec2 lmcoord;

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;
	gl_Position = gl_ModelViewMatrix * gl_Vertex;
	wpos = (gbufferModelViewInverse * gl_Position).xyz;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	normal = normalEncode(mat3(gbufferModelViewInverse) * normalize(gl_NormalMatrix * gl_Normal));
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
}
