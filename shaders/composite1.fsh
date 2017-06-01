#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 texcoord;

#include "GlslConfig"

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Material.glsl.frag"

Mask mask;

#ifdef WISDOM_AMBIENT_OCCLUSION
#ifdef HQ_AO
//=========== BLUR AO =============
vec3 blurAO (vec2 uv) {
	vec3  z  = texture2D(composite, uv).rgb;
	vec3  N  = normalDecode(z.yz);
	float a  = z.x * 0.2941176f;
	
	vec3  y  = texture2D(composite, uv + vec2(-pixel.x * 1.333333, 0.0)).rgb;
	      a += mix(z.x, y.x, max(0.0, dot(normalDecode(y.yz), N))) * 0.352941176f;
	      y  = texture2D(composite, uv + vec2( pixel.x * 1.333333, 0.0)).rgb;
	      a += mix(z.x, y.x, max(0.0, dot(normalDecode(y.yz), N))) * 0.352941176f;
	return vec3(a, z.gb);
}
//=================================
#endif
#endif

void main() {
	// build up mask
	init_mask(mask, texture2D(gaux1, texcoord).a);

	vec3 color = vec3(1.0f);
	#ifdef WISDOM_AMBIENT_OCCLUSION
	if (!mask.is_sky) {
		#ifdef HQ_AO
		color = blurAO(texcoord);
		#else
		color = texture2D(composite, texcoord).rgb;
		#endif
	}
	#endif

/* DRAWBUFFERS:3 */
	gl_FragData[0] = vec4(color, 1.0f);
}
