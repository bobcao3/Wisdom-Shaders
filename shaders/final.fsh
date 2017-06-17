#version 120
#include "compat.glsl"
#pragma optimize (on)

varying vec2 texcoord;

#include "GlslConfig"

//#define MOTION_BLUR
#define BLOOM

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Effects.glsl.frag"

//#define SSEDAA
//#define BLACK_AND_WHITE

void main() {
	#ifdef EIGHT_BIT
	vec3 color;
	bit8(color);
	#else
	#ifdef SSEDAA
	vec3 color = texture2D(composite, texcoord).rgb;
	float size = 1.0 / length(fetch_vpos(texcoord, depthtex0).xyz);
	vec3 edge = applyEffect(1.0, size,
		-1.0, -1.0, -1.0,
		-1.0,  8.0, -1.0,
		-1.0, -1.0, -1.0,
		composite, texcoord);
	vec3 blur = applyEffect(6.8, size,
		0.3, 1.0, 0.3,
		1.0, 1.6, 1.0,
		1.3, 1.0, 0.3,
		composite, texcoord);
	color = mix(color, blur, edge);
	#else
	vec3 color = texture2D(composite, texcoord).rgb;
	#endif
	#endif

	#ifdef MOTION_BLUR
	if (texture2D(gaux1, texcoord).a > 0.11) motion_blur(composite, color, texcoord, fetch_vpos(texcoord, depthtex0).xyz);
	#endif

	float exposure = get_exposure();

	#ifdef BLOOM
	color += max(vec3(0.0), bloom() * exposure * 0.5);
	#endif

	// This will turn it into gamma space
	#ifdef BLACK_AND_WHITE
	color = vec3(luma(color));
	#endif
	
	#ifdef NOISE_AND_GRAIN
	noise_and_grain(color);
	#endif
	
	#ifdef FILMIC_CINEMATIC
	filmic_cinematic(color);
	#endif
	
	tonemap(color, exposure);
	
	gl_FragColor = vec4(color, 1.0f);
}
