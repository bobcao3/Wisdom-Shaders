#version 130
#pragma optimize(on)

#include "gbuffers.inc.vsh"

VSH {
	gl_Position = ftransform();
}
