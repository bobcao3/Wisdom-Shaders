#ifndef _INCLUDE_EFFECTS
#define _INCLUDE_EFFECTS

//#define NOISE_AND_GRAIN
#ifdef NOISE_AND_GRAIN
void noise_and_grain(inout vec3 color) {
	float r = hash(texcoord * viewWidth);
	float g = hash(texcoord * viewWidth + 1000.0);
	float b = hash(texcoord * viewWidth + 4000.0);
	float w = hash(texcoord * viewWidth - 1000.0);
	w *= hash(texcoord * viewWidth - 2000.0);
	w *= hash(texcoord * viewWidth - 3000.0);
	
	color = mix(color, vec3(r,g,b) * luma(color), pow(w, 3.0));
}
#endif

//#define EIGHT_BIT
#ifdef EIGHT_BIT
void bit8(out vec3 color) {
	vec2 grid = vec2(viewWidth / viewHeight, 1.0) * 120.0;
	vec2 texc = floor(texcoord * grid) / grid;
	
	float dither = bayer_16x16(texc, grid);
	vec3 c = texture2D(composite, texc).rgb * 16.0;
	color = floor(c + dither) / 16.0;
}
#endif

//#define FILMIC_CINEMATIC
#define FILMIC_CINEMATIC_ANAMORPHIC
#ifdef FILMIC_CINEMATIC
void filmic_cinematic(inout vec3 color) {
	color = clamp(color, vec3(0.0), vec3(2.0));
	float w = luma(color);
	
	color = mix(vec3(w), max(color - vec3(w * 0.1), vec3(0.0)), 0.4 + w * 0.8);
	
	#ifdef BLOOM
	const vec2 center_avr = vec2(0.5) * 0.125 + vec2(0.0f, 0.25f) + vec2(0.000f, 0.025f);
	#define AVR_SOURCE gcolor
	#else
	const vec2 center_avr = vec2(0.5);
	#define AVR_SOURCE composite
	#endif
	vec3 center = texture2D(AVR_SOURCE, center_avr).rgb;
	color = pow(color, 0.3 * center + 1.0);
	color /= luma(center) * 0.5 + 0.5;
	color *= (normalize(max(vec3(0.1), center)) * 0.3 + 0.7);
	
	#ifdef FILMIC_CINEMATIC_ANAMORPHIC
	// 21:9
	if (viewHeight * distance(texcoord.y, 0.5) > viewWidth * 0.4285714 * 0.5)
		color *= 0.0;
	#endif
}
#endif

#ifdef MOTION_BLUR

#define MOTIONBLUR_MAX 0.1
#define MOTIONBLUR_STRENGTH 0.5
#define MOTIONBLUR_SAMPLE 6

const float dSample = 1.0 / float(MOTIONBLUR_SAMPLE);

void motion_blur(in sampler2D screen, inout vec3 color, in vec2 uv, in vec3 viewPosition) {
	vec4 worldPosition = gbufferModelViewInverse * vec4(viewPosition, 1.0) + vec4(cameraPosition, 0.0);
	vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
	vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
	vec2 prevUv = prevNdcPosition.st * 0.5 + 0.5;
	vec2 delta = uv - prevUv;
	float dist = length(delta) * 0.25;
	if (dist < 0.000025) return;
	delta = normalize(delta);
	dist = min(dist, MOTIONBLUR_MAX);
	int num_sams = int(dist / MOTIONBLUR_MAX * MOTIONBLUR_SAMPLE) + 1;
	dist *= MOTIONBLUR_STRENGTH;
	delta *= dist * dSample;
	for(int i = 1; i < num_sams; i++) {
		uv += delta;
		color += texture2D(screen, uv).rgb;
	}
	color /= float(num_sams);
}
#endif

vec3 applyEffect(float total, float size,
	float a00, float a01, float a02,
	float a10, float a11, float a12,
	float a20, float a21, float a22,
	sampler2D sam, vec2 uv) {
	
	vec3 color = texture2D(sam, uv).rgb * a11;

	color += texture2D(sam, uv + size * vec2(-pixel.x, pixel.y)).rgb * a00;
	color += texture2D(sam, uv + size * vec2(0.0, pixel.y)).rgb * a01;
	color += texture2D(sam, uv + size * pixel).rgb * a00;
	color += texture2D(sam, uv + size * vec2(-pixel.x, 0.0)).rgb * a00;
	color += texture2D(sam, uv + size * vec2(pixel.x, 0.0)).rgb * a00;
	color += texture2D(sam, uv - size * pixel).rgb * a00;
	color += texture2D(sam, uv + size * vec2(0.0, -pixel.y)).rgb * a01;
	color += texture2D(sam, uv + size * vec2(pixel.x, -pixel.y)).rgb * a00;
	
	return max(color / total, vec3(0.0));
}

vec3 saturation(vec3 rgbColor, float s) {
	return mix(vec3(luma(rgbColor)), rgbColor, s);
}

//#define DOF
#if (defined(BLOOM) || defined(DOF))

// 4x4 bicubic filter using 4 bilinear texture lookups 
// See GPU Gems 2: "Fast Third-Order Texture Filtering", Sigg & Hadwiger:
// http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter20.html

// w0, w1, w2, and w3 are the four cubic B-spline basis functions
float w0(float a) {
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a) {
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a) {
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a) {
    return (1.0/6.0)*(a*a*a);
}

// g0 and g1 are the two amplitude functions
float g0(float a) {
    return w0(a) + w1(a);
}

float g1(float a) {
    return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a) {
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a) {
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 texture_Bicubic(sampler2D tex, vec2 uv)
{

	uv = uv * vec2(viewWidth, viewHeight) - 1.0;
	vec2 iuv = floor( uv );
	vec2 fuv = uv - iuv;

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);
	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) + 0.5) * texelSize;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) + 0.5) * texelSize;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) + 0.5) * texelSize;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) + 0.5) * texelSize;
	
    return g0(fuv.y) * (g0x * texture2D(tex, p0)  +
                        g1x * texture2D(tex, p1)) +
           g1(fuv.y) * (g0x * texture2D(tex, p2)  +
                        g1x * texture2D(tex, p3));
}

#define DIRTY_LENS
#define DIRTY_LENS_TEXTURE

vec3 bloom(inout vec3 c) {
	vec2 tex = texcoord * 0.25;
	vec2 pix_offset = 1.0 / vec2(viewWidth, viewHeight);
	vec3 color = texture_Bicubic(gcolor, tex - pix_offset).rgb;
	tex = texcoord * 0.125 + vec2(0.0f, 0.35f) + vec2(0.000f, 0.035f);
	color += texture_Bicubic(gcolor, tex - pix_offset).rgb;
	tex = texcoord * 0.0625 + vec2(0.125f, 0.35f) + vec2(0.030f, 0.035f);
	color += texture_Bicubic(gcolor, tex - pix_offset).rgb;
	tex = texcoord * 0.03125 + vec2(0.1875f, 0.35f) + vec2(0.060f, 0.035f);
	color += texture_Bicubic(gcolor, tex - pix_offset).rgb;
	tex = texcoord * 0.015625 + vec2(0.21875f, 0.35f) + vec2(0.090f, 0.035f);
	color += texture_Bicubic(gcolor, tex - pix_offset).rgb;
	
	color *= 0.2;
	float l = luma(color);
	
	// Dirty lens
	#ifdef DIRTY_LENS
	vec2 ext_tex = (texcoord - 0.5) * 0.5 + 0.5;
	tex = ext_tex * 0.03125 + vec2(0.1875f, 0.35f) + vec2(0.060f, 0.035f);
	vec3 color_huge = texture_Bicubic(gcolor, tex - pix_offset).rgb;
	tex = ext_tex * 0.015625 + vec2(0.21875f, 0.35f) + vec2(0.090f, 0.035f);
	color_huge += texture_Bicubic(gcolor, tex - pix_offset).rgb;
	
	float lh = luma(color_huge);
	if (lh > 0.4) {
		vec2 uv = texcoord;
		uv.y = uv.y / viewWidth * viewHeight;
		float col = smoothstep(0.4, 0.6, lh);
		
		#ifdef DIRTY_LENS_TEXTURE
		vec3 lens = texture2D(gaux3, texcoord).rgb;
		c = mix(c, mix(color, color_huge * lens, 0.7), lens * col);
		#else
		float n = abs(simplex2D(uv * 10.0));
		n += simplex2D(uv * 6.0 + 0.4) * 0.4;
		n += simplex2D(uv * 3.0 + 0.7);
		
		n = clamp(n * 0.3, 0.0, 1.0);
		
		c = mix(c, mix(color, color_huge, 0.7), n * col * 0.5);
		#endif
	}
	#endif
	
	return color * l;
}

void dof(inout vec3 color) {
	vec3 blur = applyEffect(6.8, 1.0,
		0.3, 1.0, 0.3,
		1.0, 1.6, 1.0,
		0.3, 1.0, 0.3,
		composite, texcoord);
	float pcoc = abs(linearizeDepth(texture2D(depthtex0, texcoord).r) - linearizeDepth(centerDepthSmooth));
	
	color = mix(color, blur, pcoc);
}
#endif

#endif
