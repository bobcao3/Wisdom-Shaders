#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 texcoord;

#include "GlslConfig"

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Material.glsl.frag"
#include "Lighting.glsl.frag"
#include "Atomosphere.glsl.frag"

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

#ifdef VOLUMETRIC_CLOUDS

#endif

void main() {
	// build up mask
	init_mask(mask, texture2D(gaux1, texcoord).a);

	vec3 color = vec3(1.0f);
	vec4 cloud = vec4(0.0f);
	if (!mask.is_sky) {
	#ifdef WISDOM_AMBIENT_OCCLUSION
		#ifdef HQ_AO
		color = blurAO(texcoord);
		#else
		color = texture2D(composite, texcoord).rgb;
		#endif
	#endif
	} else {
	#ifdef VOLUMETRIC_CLOUDS
		vec4 viewPosition = fetch_vpos(texcoord, 1.0);
		float dotS = max(dot(normalize(viewPosition.xyz), lightPosition), 0.0);
		
		vec4 worldPosition = normalize(gbufferModelViewInverse * viewPosition) * 512.0;
		worldPosition.y += cameraPosition.y;

		cloud = volumetric_clouds(worldPosition.xyz - vec3(0.0, cameraPosition.y, 0.0), cameraPosition, dotS);
	#endif
	}
		
/* DRAWBUFFERS:13 */
	gl_FragData[0] = cloud;
	gl_FragData[1] = vec4(color, 1.0f);
}
