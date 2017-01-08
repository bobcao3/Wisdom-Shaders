#version 130
#pragma optimize(on)

#define SHADOW_MAP_BIAS 0.9

out vec2 texcoord;
out vec4 color;

#define GlobalIllumination

void main() {
	gl_Position = ftransform();
	color = gl_Color;
	#ifdef GlobalIllumination
	color.rgb *= max(0.0, dot(gl_Normal, vec3(0.0, 1.0, 0.0)));
	#endif
	lowp float dist = length(gl_Position.xy);
	lowp float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	gl_Position.xy /= distortFactor;
	texcoord = gl_MultiTexCoord0.st;
}
