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

const float centerDepthHalflife = 2.5f;
uniform float centerDepthSmooth;

const int colortex0Format = RGBA8;
const int colortex1Format = RGBA32F;
const int gnormalFormat = RGBA16;
const int compositeFormat = R11F_G11F_B10F;
const int gaux1Format = RGBA8;
const int gaux2Format = RGBA8;
const int gaux3Format = RGBA32F;
const int gaux4Format = RGBA8;

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

//#define TONEMAP_METHOD RomBinDaHouseToneMapping
#define luma(color)	dot(color,vec3(0.2126, 0.7152, 0.0722))

in float centerDepth;

#define DOF_FADE_RANGE 0.08
#define DOF_CLEAR_RADIUS 0.1
#define DOF_NEARVIEWBLUR
//#define DOF

#define linearizeDepth(depth) (2.0 * near) / (far + near - depth * (far - near))

#ifdef DOF
vec3 dof(vec3 color, vec2 uv, float depth, in vec3 blurcolor) {
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
	return mix(color, blurcolor, fade * 0.6);
}
#endif

#define MOTION_BLUR

#ifdef MOTION_BLUR
uniform mat4 gbufferModelViewInverse;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;

#define MOTIONBLUR_MAX 0.1
#define MOTIONBLUR_STRENGTH 0.5
#define MOTIONBLUR_SAMPLE 12

vec3 motionBlur(vec3 color, in vec2 uv, in vec4 viewPosition) {
	vec4 worldPosition = gbufferModelViewInverse * viewPosition + vec4(cameraPosition, 0.0);
	vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
	vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
	vec2 prevUv = (prevNdcPosition * 0.5 + 0.5).st;
	vec2 delta = uv - prevUv;
	float dist = length(delta) * 0.25;
	delta = normalize(delta);
	dist = min(dist, MOTIONBLUR_MAX);
	int num_sams = int(dist / MOTIONBLUR_MAX * MOTIONBLUR_SAMPLE) + 1;
	dist *= MOTIONBLUR_STRENGTH;
	delta *= dist / float(MOTIONBLUR_SAMPLE);
	for(int i = 1; i < num_sams; i++) {
		uv += delta;
		color += texture(Output, uv).rgb;
	}
	color /= float(num_sams);
	return color;
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

vec3 whitePreservingLumaBasedReinhardToneMapping(in vec3 color) {
	const float white = 1.03;
	float l = luma(color);
	float toneMappedLuma = l * (1. + l / (white * white)) / (1. + l);
	color *= toneMappedLuma / l;
	color = pow(color, vec3(1. / gamma));
	return vec3(color);
}

vec3 RomBinDaHouseToneMapping(vec3 color) {
	color = exp( -1.0 / ( 2.72*color + 0.15 ) );
	color = pow(color, vec3(1. / gamma));
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
	dist = clamp(dist * 1.9 - 0.75, 0.0, 1.0);
	dist = smoothstep(0.0, 1.0, dist);
	return color.rgb * (1.0 - dist);
}

#define BLOOM

const float offset[9] = float[] (0.0, 1.4896, 3.4757, 5.4619, 7.4482, 9.4345, 11.421, 13.4075, 15.3941);
const float weight[9] = float[] (0.066812, 0.129101, 0.112504, 0.08782, 0.061406, 0.03846, 0.021577, 0.010843, 0.004881);

vec3 blur() {
	vec3 color = texture(gcolor, texcoord).rgb * weight[0];
	vec2 direction = vec2(0.0, 0.0018) / viewWidth * viewHeight;
	for(int i = 1; i < 9; i++) {
		color += texture(gcolor, texcoord + direction * offset[i]).rgb * weight[i];
		color += texture(gcolor, texcoord - direction * offset[i]).rgb * weight[i];
	}
	return color;
}

#define FINAL_COLOR_ADJUST
#ifdef FINAL_COLOR_ADJUST
vec3 rgbToHsl(vec3 rgbColor) {
	rgbColor = clamp(rgbColor, vec3(0.0), vec3(1.0));
	float h, s, l;
	float r = rgbColor.r, g = rgbColor.g, b = rgbColor.b;
	float minval = min(r, min(g, b));
	float maxval = max(r, max(g, b));
	float delta = maxval - minval;
	l = ( maxval + minval ) / 2.0;
	if (delta == 0.0) {
		h = 0.0;
		s = 0.0;
	} else {
		if ( l < 0.5 )
		s = delta / ( maxval + minval );
		else
		s = delta / ( 2.0 - maxval - minval );

		float deltaR = (((maxval - r) / 6.0) + (delta / 2.0)) / delta;
		float deltaG = (((maxval - g) / 6.0) + (delta / 2.0)) / delta;
		float deltaB = (((maxval - b) / 6.0) + (delta / 2.0)) / delta;

		if(r == maxval)
		h = deltaB - deltaG;
		else if(g == maxval)
		h = ( 1.0 / 3.0 ) + deltaR - deltaB;
		else if(b == maxval)
		h = ( 2.0 / 3.0 ) + deltaG - deltaR;

		if ( h < 0.0 )
		h += 1.0;
		if ( h > 1.0 )
		h -= 1.0;
	}
	return vec3(h, s, l);
}

float hueToRgb(float v1, float v2, float vH) {
	vH += float(vH < 0.0);
	vH -= float(vH > 1.0);
	if ((6.0 * vH) < 1.0) return (v1 + (v2 - v1) * 6.0 * vH);
	if ((2.0 * vH) < 1.0) return v2;
	if ((3.0 * vH) < 2.0) return (v1 + ( v2 - v1 ) * ( ( 2.0 / 3.0 ) - vH ) * 6.0);
	return v1;
}

vec3 hslToRgb(vec3 hslColor) {
	hslColor = clamp(hslColor, vec3(0.0), vec3(1.0));
	float r, g, b;
	float h = hslColor.r, s = hslColor.g, l = hslColor.b;
	if (s == 0.0) {
		r = l;
		g = l;
		b = l;
	} else {
		float v1, v2;
		if (l < 0.5)
		v2 = l * (1.0 + s);
		else
		v2 = (l + s) - (s * l);

		v1 = 2.0 * l - v2;

		r = hueToRgb(v1, v2, h + (1.0 / 3.0));
		g = hueToRgb(v1, v2, h);
		b = hueToRgb(v1, v2, h - (1.0 / 3.0));
	}
	return vec3(r, g, b);
}

vec3 colorBalance(vec3 rgbColor, vec3 hslColor, vec3 s, vec3 m, vec3 h) {
	s *= clamp((hslColor.bbb - 0.333) / -0.25 + 0.5, 0.0, 1.0) * 0.7;
	m *= clamp((hslColor.bbb - 0.333) /  0.25 + 0.5, 0.0, 1.0) *
	clamp((hslColor.bbb + 0.333 - 1.0) / -0.25 + 0.5, 0.0, 1.0) * 0.7;
	h *= clamp((hslColor.bbb + 0.333 - 1.0) /  0.25 + 0.5, 0.0, 1.0) * 0.7;
	vec3 newColor = rgbColor;
	newColor += s;
	newColor += m;
	newColor += h;
	newColor = clamp(newColor, vec3(0.0), vec3(1.0));
	vec3 newHslColor = rgbToHsl(newColor);
	newHslColor.b = hslColor.b;
	newColor = hslToRgb(newHslColor);
	return newColor;
}

vec3 vibrance(vec3 hslColor, vec3 rgb, float v) {
	hslColor.g = pow(hslColor.g, v * clamp(0.0, 1.0 - rgb.r * 0.36 + rgb.b * 0.21 + rgb.g * 0.26, 1.0));
	return hslColor;
}

void color_adjust(inout vec3 c) {
	vec3 hC = rgbToHsl(c);
	c = colorBalance(c, hC, vec3(0.03, 0.02, 0.09), vec3(0.08, 0.11, 0.13), vec3(-0.03, -0.01, 0.0));
	hC = vibrance(hC, c, 0.95);
	c = mix(c, hslToRgb(hC), clamp(0.0, c.r + c.b * 0.1 + c.g * 0.05, 1.0));
}

#endif

void main() {
	vec3 color = texture(Output, texcoord).rgb;
	vec3 blurcolor = blur();

	#ifdef MOTION_BLUR
	vec4 viewpos = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, texture(depthtex0, texcoord).r * 2.0 - 1.0, 1.0f);
	viewpos /= viewpos.w;
	color = motionBlur(color, texcoord, viewpos);
	#endif

	#ifdef DOF
	color = dof(color, texcoord, texture(depthtex0, texcoord).r, blurcolor);
	#endif
	#ifdef BLOOM
	color += luma(blurcolor) * blurcolor * 0.3;
	#endif

	color = pow(color, vec3(1. / gamma));
	#ifdef FINAL_COLOR_ADJUST
	color = clamp(vec3(0.0), color, vec3(1.0));
	color_adjust(color);
	#endif
	color = vignette(color);

	gl_FragColor = vec4(color, 1.0f);
}
