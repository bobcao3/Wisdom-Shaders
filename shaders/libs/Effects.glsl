#ifndef _INCLUDE_EFFECTS
#define _INCLUDE_EFFECTS

#define NOISE_AND_GRAIN
#ifdef NOISE_AND_GRAIN
void noise_and_grain(inout vec3 color) {
	float r = hash(uv * viewWidth);
	float g = hash(uv * viewWidth + 1000.0);
	float b = hash(uv * viewWidth + 4000.0);
	float w = hash(uv * viewWidth - 1000.0);
	w *= hash(uv * viewWidth - 2000.0);
	w *= hash(uv * viewWidth - 3000.0);

	float dist = distance(uv, vec2(0.5f));
    dist = dist * 1.7 - 0.65;
    dist = fma(smoothstep(0.0, 1.0, dist), 0.7, 0.3);
	
	color += abs(vec3(1.0) - vec3(r,g,b)) * 0.002 * dist;
}
#endif

//#define EIGHT_BIT
#ifdef EIGHT_BIT
void bit8(sampler2D tex, vec2 uv, out vec3 color) {
	vec2 grid = vec2(viewWidth / viewHeight, 1.0) * 120.0;
	vec2 texc = floor(uv * grid) / grid;

	#ifndef BAYER_64
	#define BAYER_64
	float dither = bayer_64x64(uv, vec2(viewWidth, viewHeight));
	bayer_64 = dither;
	#else
	float dither = bayer_64;
	#endif
	vec3 c = texture2D(tex, texc).rgb * 16.0;
	color = floor(c + dither) / 16.0;
}
#endif

#define FILMIC_CINEMATIC_ANAMORPHIC
#ifdef FILMIC_CINEMATIC
void filmic_cinematic(inout vec3 color) {
	color = clamp(color, vec3(0.0), vec3(2.0));
	float w = luma(color);

	color = mix(vec3(w), max(color - vec3(w * 0.1), vec3(0.0)), 0.4 + w * 0.8);

	#ifdef BLOOM
	const vec2 center_avr = vec2(0.5) * 0.015625 + vec2(0.21875f, 0.25f) + vec2(0.090f, 0.03f);
	#define AVR_SOURCE colortex0
	#else
	const vec2 center_avr = vec2(0.5);
	#define AVR_SOURCE gaux2
	#endif
	vec3 center = texture2D(AVR_SOURCE, center_avr).rgb;
	color = pow(color, 0.3 * center + 1.0);
	color /= luma(center) * 0.5 + 0.5;
	color *= (normalize(max(vec3(0.1), center)) * 0.3 + 0.7);
	color += center * 0.1;

	#ifdef FILMIC_CINEMATIC_ANAMORPHIC
	// 21:9
	if (viewHeight * distance(uv.y, 0.5) > viewWidth * 0.4285714 * 0.5)
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

#ifdef BLOOM


vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);

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

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) + 0.5) * texelSize;
	vec4 t0 = texture2D(tex, p0);
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) + 0.5) * texelSize;
	vec4 t1 = texture2D(tex, p1);
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) + 0.5) * texelSize;
	vec4 t2 = texture2D(tex, p2);
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) + 0.5) * texelSize;
	vec4 t3 = texture2D(tex, p3);

    return g0(fuv.y) * (g0x * t0  +
                        g1x * t1) +
           g1(fuv.y) * (g0x * t2  +
                        g1x * t3);
}

#define DIRTY_LENS

vec3 bloom(inout vec3 c, in vec2 uv, float sensitivity, out vec3 rawblur) {
	vec2 tex = uv * 0.25;
	vec2 pix_offset = vec2(-.5, -.5) / vec2(viewWidth, viewHeight);
	vec3 color = vec3(0.0);
	vec4 s0 = texture_Bicubic(colortex0, tex - pix_offset);
	    tex = uv * 0.125 + vec2(0.0f, 0.25f) + vec2(0.000f, 0.03f);
	vec4 s1 = texture_Bicubic(colortex0, tex - pix_offset);
	    tex = uv * 0.0625 + vec2(0.125f, 0.25f) + vec2(0.030f, 0.03f);
	vec4 s2 = texture_Bicubic(colortex0, tex - pix_offset);
	    tex = uv * 0.03125 + vec2(0.1875f, 0.25f) + vec2(0.060f, 0.03f);
	vec4 s3 = texture_Bicubic(colortex0, tex - pix_offset);
	    tex = uv * 0.015625 + vec2(0.21875f, 0.25f) + vec2(0.090f, 0.03f);
	vec4 s4 = texture_Bicubic(colortex0, tex - pix_offset);

	rawblur = (s0.rgb + s1.rgb + s2.rgb + s3.rgb + s4.rgb) * 0.2;

	//float l = luma(color.rgb);
	color = (s0.rgb * s0.a + s1.rgb * s1.a + s2.rgb * s2.a + s3.rgb * s3.a + s4.rgb * s4.a) * 0.2;

	// Dirty lens
	#ifdef DIRTY_LENS
	vec2 ext_tex = (uv - 0.5) * 0.5 + 0.5;
	tex = ext_tex * 0.03125 + vec2(0.1875f, 0.25f) + vec2(0.060f, 0.03f);
	vec3 color_huge = texture_Bicubic(colortex0, tex - pix_offset).rgb;
	tex = ext_tex * 0.015625 + vec2(0.21875f, 0.25f) + vec2(0.090f, 0.03f);
	color_huge += texture_Bicubic(colortex0, tex - pix_offset).rgb;

	float lh = luma(color_huge);
	if (lh > 0.2) {
		vec2 uv = uv;
		uv.y = uv.y / viewWidth * viewHeight;
		float col = smoothstep(0.2, 0.6, lh);

		vec3 lens = texture_Bicubic(gaux3, uv).rgb;
		c = mix(c, mix(color, color_huge * lens, 0.7), lens * col);
	}
	#endif

	return color;
}
#endif

#endif
