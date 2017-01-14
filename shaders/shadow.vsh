#version 130
#pragma optimize(on)

#define SHADOW_MAP_BIAS 0.9

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform float rainStrength;
uniform float frameTimeCounter;

out vec2 texcoord;
out vec4 color;

#define rand(co) fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453)

#define GlobalIllumination

#define WAVING_SHADOW

void main() {
	#ifdef WAVING_SHADOW
	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	if((blockId == 31.0 || blockId == 37.0 || blockId == 38.0) && gl_MultiTexCoord0.t < mc_midTexCoord.t) {
		float blockId = mc_Entity.x;
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand(position.xy) * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.x += sin(rand(position.xz) * 10.0 + time) * 0.2 * reset * maxStrength;
		position.z += sin(rand(position.yz) * 10.0 + time) * 0.2 * reset * maxStrength;
	}
	gl_Position = gl_ModelViewMatrix * position;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	#else
	gl_Position = ftransform();
	#endif

	color = gl_Color;
	#ifdef GlobalIllumination
	color.rgb *= max(0.0, dot(gl_Normal, vec3(0.0, 1.0, 0.0)));
	#endif
	lowp float dist = length(gl_Position.xy);
	lowp float distortFactor = (1.0 - SHADOW_MAP_BIAS) + dist * SHADOW_MAP_BIAS;
	gl_Position.xy /= distortFactor;
	texcoord = gl_MultiTexCoord0.st;
}
