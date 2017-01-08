#version 130
#pragma optimize(on)

#define NORMALS

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

uniform mat4 gbufferModelViewInverse;
uniform sampler2D noisetex;
uniform float rainStrength;
uniform float frameTimeCounter;

out lowp vec4 color;
out lowp vec3 normal;
out highp vec2 texcoord;
out highp vec3 wpos;
out lowp vec2 lmcoord;
out float flag;

#ifdef NORMALS
out vec3 tangent;
out vec3 binormal;
out vec3 viewVector;
#endif

#define ParallaxOcculusion
#ifdef ParallaxOcculusion
out vec2 midTexCoord;
out vec3 TangentFragPos;
out vec4 vtexcoordam;
#endif

#define rand(co) fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453)

#include "gbuffers.inc.vsh"

VSH {
	color = gl_Color;

	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
	flag = 0.7;
	if((blockId == 31.0 || blockId == 37.0 || blockId == 38.0) && gl_MultiTexCoord0.t < mc_midTexCoord.t) {
		float blockId = mc_Entity.x;
		vec3 noise = texture2D(noisetex, position.xz / 256.0).rgb;
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand(position.xy) * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.x += sin(rand(position.xz) * 10.0 + time) * 0.2 * reset * maxStrength;
		position.z += sin(rand(position.yz) * 10.0 + time) * 0.2 * reset * maxStrength;

		flag = 0.51;
	}	else if(mc_Entity.x == 18.0 || mc_Entity.x == 106.0 || mc_Entity.x == 161.0 || mc_Entity.x == 175.0) {
		float maxStrength = 1.0 + rainStrength * 0.5;
		float time = frameTimeCounter * 3.0;
		float reset = cos(rand(position.xy) * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength, 0.1));
		position.x += sin(rand(position.xz) * 10.0 + time) * 0.07 * reset * maxStrength;
		position.z += sin(rand(position.yz) * 10.0 + time) * 0.07 * reset * maxStrength;

		flag = 0.51;
	} else if (blockId == 83.0 || blockId == 39 || blockId ==40 || blockId == 6.0 || blockId == 104 || blockId == 105 || blockId == 115 || blockId == 141 || blockId == 142) {
		flag = 0.51;
	}

	gl_Position = gl_ModelViewMatrix * position;
	viewVector = gl_Position.xyz;
	wpos = (gbufferModelViewInverse * gl_Position).xyz;
	gl_Position = gl_ProjectionMatrix * gl_Position;
	normal = normalize(gl_Normal);
	texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	#ifdef NORMALS
	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = vec3( 0.0,  0.0, -1.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = vec3( 0.0,  0.0,  1.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0,  1.0);
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0,  0.0,  1.0);
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = vec3( 1.0,  0.0,  0.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = vec3(-1.0,  0.0,  0.0);
		binormal = vec3( 0.0, -1.0,  0.0);
	}
	#endif

	#ifdef ParallaxOcculusion
	midTexCoord = (gl_TextureMatrix[0] *  mc_midTexCoord).st;
	vec2 texcoordminusmid = texcoord - midTexCoord;
	vtexcoordam.pq  = abs(texcoordminusmid) * 2;
	vtexcoordam.st  = min(texcoord, midTexCoord - texcoordminusmid);
	mat3 TBN = mat3(
		tangent.x, binormal.x, normal.x,
		tangent.y, binormal.y, normal.y,
		tangent.z, binormal.z, normal.z);
	TangentFragPos  = normalize(TBN * (wpos.xyz - vec3(0.0, 1.67, 0.0)));
	#endif
}
