#version 130
#pragma optimize(on)

const int RGB8 = 0, RGBA32F = 1, R11F_G11F_B10F = 2, RGBA16 = 3, RGBA8 = 4, RGB8_SNORM = 5, RGB32UI = 6;
#define GAlbedo colortex0
#define GWPos colortex1
#define GNormals gnormal
#define Output composite
#define GSpecular gaux1
#define mcData gaux2
#define WaterWPos gaux3

const int colortex0Format = RGBA8;
const int colortex1Format = RGBA32F;
const int gnormalFormat = RGBA16;
const int compositeFormat = R11F_G11F_B10F;
const int gaux1Format = RGBA8;
const int gaux2Format = RGBA8;
const int gaux3Format = RGBA32F;
const int gaux4Format = RGBA8;
const int noiseTextureResolution = 80;

in vec2 texcoord;

uniform sampler2D depthtex0;
uniform sampler2D Output;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D GWPos;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform float viewHeight;
uniform float viewWidth;
uniform float near;
uniform float far;
uniform float aspectRatio;

const float gamma = 2.2;

#define TONEMAP_METHOD whitePreservingLumaBasedReinhardToneMapping
#define luma(color)	dot(color,vec3(0.2126, 0.7152, 0.0722))

in float centerDepth;

#define DOF_FADE_RANGE 0.15
#define DOF_CLEAR_RADIUS 0.2
#define DOF_NEARVIEWBLUR
//#define DOF

#define linearizeDepth(depth) (2.0 * near) / (far + near - depth * (far - near))

#ifdef DOF
vec3 dof(vec3 color, vec2 uv, float depth) {
	float linearFragDepth = linearizeDepth(depth);
	float linearCenterDepth = linearizeDepth(centerDepth);
	float delta = linearFragDepth - linearCenterDepth;
	#ifdef DOF_NEARVIEWBLUR
	float fade = smoothstep(0.0, DOF_FADE_RANGE, clamp(abs(delta) - DOF_CLEAR_RADIUS, 0.0, DOF_FADE_RANGE));
	#else
	float fade = smoothstep(0.0, DOF_FADE_RANGE, clamp(delta - DOF_CLEAR_RADIUS, 0.0, DOF_FADE_RANGE));
	#endif
	#ifdef TILT_SHIFT
	float vin_dist = distance(texcoord.st, vec2(0.5f));
	vin_dist = clamp(vin_dist * 1.7 - 0.65, 0.0, 1.0); //各种凑魔数
	vin_dist = smoothstep(0.0, 1.0, vin_dist);
	fade = max(vin_dist, fade);
	#endif
	if(fade < 0.001) return color;
	vec2 offset = vec2(1.0 * aspectRatio / viewWidth, 1.0 / viewHeight);
	vec3 blurColor = vec3(0.0);
	//0.12456 0.10381 0.12456
	//0.10380 0.08651 0.10380
	//0.12456 0.10381 0.12456
	blurColor += texture(Output, uv + offset * vec2(-1.0, -1.0)).rgb * 0.12456;
	blurColor += texture(Output, uv + offset * vec2(0.0, -1.0), 1.0).rgb * 0.10381;
	blurColor += texture(Output, uv + offset * vec2(1.0, -1.0)).rgb * 0.12456;
	blurColor += texture(Output, uv + offset * vec2(-1.0, 0.0), 1.0).rgb * 0.10381;
	blurColor += texture(Output, uv, 3.0).rgb * 0.08651;
	blurColor += texture(Output, uv + offset * vec2(1.0, 0.0), 1.0).rgb * 0.10381;
	blurColor += texture(Output, uv + offset * vec2(-1.0, 1.0)).rgb * 0.12456;
	blurColor += texture(Output, uv + offset * vec2(0.0, 1.0), 1.0).rgb * 0.10381;
	blurColor += texture(Output, uv + offset * vec2(1.0, 1.0)).rgb * 0.12456;
	return mix(color, blurColor, fade);
}
#endif

/*
vec3 lumaBasedReinhardToneMapping(vec3 color) {
	float l = luma(color);
	float toneMappedLuma = l / (1. + l);
	color *= toneMappedLuma / l;
	color = pow(color, vec3(1. / gamma));
	return color;
}
*/
vec3 whitePreservingLumaBasedReinhardToneMapping(in vec3 color) {
	const float white = 1.63;
	float l = luma(color);
	float toneMappedLuma = l * (1. + l / (white * white)) / (1. + l);
	color *= toneMappedLuma / l;
	color = pow(color, vec3(1. / gamma));
	return vec3(color);
}
/*
vec3 RomBinDaHouseToneMapping(vec3 color) {
	color = exp( -1.0 / ( 2.72*color + 0.15 ) );
	color = pow(color, vec3(1. / gamma));
	return color;
}

vec3 filmicToneMapping(vec3 color) {
	color = max(vec3(0.), color - vec3(0.004));
	color = (color * (6.2 * color + .5)) / (color * (6.2 * color + 1.7) + 0.06);
	return color;
}

vec3 Uncharted2ToneMapping(vec3 color) {
	const float A = 0.65;
	const float B = 0.30;
	const float C = 0.10;
	const float D = 0.20;
	const float E = 0.02;
	const float F = 0.30;
	const float W = 11.2;
	const float exposure = 2.;
	color *= exposure;
	color = ((color * (A * color + C * B) + D * E) / (color * (A * color + B) + D * F)) - E / F;
	float white = ((W * (A * W + C * B) + D * E) / (W * (A * W + B) + D * F)) - E / F;
	color /= white;
	color = pow(color, vec3(1. / gamma));
	return color;
}
*/

vec3 vignette(vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5f));
	dist = clamp(dist * 1.7 - 0.65, 0.0, 1.0);
	dist = smoothstep(0.0, 1.0, dist);
	return color.rgb * (1.0 - dist);
}

#define BLOOM
#ifdef BLOOM
vec3 bloom() {
	vec3 bloom = vec3(0.0);//texture(gcolor, texcoord).rgb;
	const float sbias = 1.0 / 4.0f;
	for (int i = 1; i < 7; i++) {
		float height_bias = viewWidth / viewWidth;
		vec3 data = texture(gcolor, texcoord + vec2(0.0, 0.0061) * float(i) * height_bias).rgb;
		float de = 1.0 / float(i);
		bloom += data * de;

		data = texture(gcolor, texcoord + vec2(0.0, -0.0061) * float(i) * height_bias).rgb;
		bloom += data * de;
	}
	return bloom * clamp(0.0, luma(bloom), 5.0) * 0.105;
}
#endif

void main() {
	vec3 color = texture(Output, texcoord).rgb;
	#ifdef DOF
		color = dof(color, texcoord, texture(depthtex0, texcoord).r);
	#endif

	#ifdef BLOOM
	color += bloom();
	#endif
	color = vignette(color);
	color = TONEMAP_METHOD(color);

	gl_FragColor = vec4(color, 1.0f);
}
