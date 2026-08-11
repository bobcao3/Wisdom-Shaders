#version 120
#include "compat.glsl"

const int RGB8 = 0, R11F_G11F_B10F = 1, RGB10_A2 = 2, RGBA16 = 3, RGBA8 = 4, RG16 = 5, R8 = 6, RGBA4 = 7;

const int colortex0Format = RGB10_A2;
const int colortex1Format = RGBA16;
const int colortex8Format = RGBA8;
const int colortex9Format = R8;
const int colortex10Format = RGBA4;
const int gnormalFormat = RGBA16;
const int compositeFormat = R11F_G11F_B10F;
const int gaux1Format = RGBA8;
const int gaux2Format = RGBA16;
const int gaux3Format = RGB8;
const int gaux4Format = RGBA8;
const int noiseTextureResolution = 512;

const float eyeBrightnessHalflife = 18.5f;
const float wetnessHalflife = 400.0f;
const float drynessHalflife = 20.0f;
const float centerDepthHalflife = 2.5f;

varying vec2 texcoord;

#include "GlslConfig"

#include "CompositeUniform.glsl.frag"
#include "Utilities.glsl.frag"
#include "Material.glsl.frag"
#include "Lighting.glsl.frag"
#include "Atomosphere.glsl.frag"

vec2 mclight = texture2D(gaux2, texcoord).xy;

Mask mask;
Material land;


void main() {
	// rebuild hybrid flag
	vec3 normaltex = texture2D(gnormal, texcoord).rgb;
	vec4 water_normal_tex = texture2D(colortex1, texcoord);
	if (water_normal_tex.b == 1.0) water_normal_tex.b = 0.0;
	float flag = (normaltex.b < 0.11 && normaltex.b > 0.01) ? normaltex.b : max(normaltex.b, water_normal_tex.b);
	if (normaltex.b < 0.09 && water_normal_tex.b > 0.9) flag = 0.99;
	if (normaltex.b > 0.19 && normaltex.b < 0.21 && water_normal_tex.b > 0.98) flag = 0.45;


	// build up mask
	init_mask(mask, flag);

	vec3 color = vec3(0.0f);
	if (!mask.is_sky) {
		material_sample(land, texcoord);
		color.r = calcAO(land.N, land.cdepth, land.vpos, texcoord);
		#ifdef HQ_AO
		color.gb = normaltex.rg;
		#endif
	}

	// rebuild hybrid data
	vec4 specular_data = flag > 0.89f ? texture2D(colortex8, texcoord) : texture2D(gaux1, texcoord);
	if (flag > 0.89f) specular_data.b = water_normal_tex.a;
	specular_data.a = flag;

/* DRAWBUFFERS:234 */
	gl_FragData[0] = vec4(normaltex.xy, water_normal_tex.xy);
	gl_FragData[1] = vec4(color, 1.0f);
	gl_FragData[2] = specular_data;
}
