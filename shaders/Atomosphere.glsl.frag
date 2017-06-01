#ifndef _INCLUDE_ATMOS
#define _INCLUDE_ATMOS

const vec3 wavelengthRGB = vec3(0.7, 0.5461, 0.4358);
const vec3 skyOriginalRGB = vec3(1.0) / pow(wavelengthRGB, vec3(4.0));
const vec3 skyRGB = skyOriginalRGB / skyOriginalRGB.b;

void calc_fog(in float depth, in float start, in float end, inout vec3 original, in vec3 col) {
	original = mix(col, original, pow(clamp((end - depth) / (end - start), 0.0, 1.0), (1.0 - rainStrength) * 0.5 + 0.5));
}

void calc_fog_height(Material mat, in float start, in float end, inout vec3 original, in vec3 col) {
	float coeif = 1.0 - clamp((end - mat.cdepth) / (end - start), 0.0, 1.0);
	coeif *= clamp((end - mat.wpos.y) / (end - start), 0.0, 1.0);
	coeif = pow(coeif, (1.0 - rainStrength) * 0.5 + 0.5);
	original = mix(original, col, coeif);
}

vec3 calc_atmosphere(in vec3 sphere, in vec3 vsphere) {
	float h = abs(normalize(sphere).y);
	vec3 at = vec3(skyRGB * (1.0 - 0.6 * pow(h, 0.75)));
	at += pow(1.0 - h, 3.0) * 0.5 * (vec3(1.0)) * clamp(length(sphere) / 512.0, 0.0, 1.0);
	
	vec3 rain = at;
	calc_fog(length(sphere), 1.0, 512.0, rain, vec3(2.0));
	at = mix(at, rain, rainStrength) * luma(ambient);
	
	at += luma(suncolor) * 0.01 * max(0.0, dot(vsphere, lightPosition));
	at += luma(suncolor) * 0.01 * pow(max(0.0, dot(vsphere, lightPosition)), 4.0);
	at += luma(suncolor) * 0.01 * pow(max(0.0, dot(vsphere, lightPosition)), 8.0);
	at += luma(suncolor) * 0.1 * pow(abs(dot(vsphere, lightPosition)), 30.0);
	
	return at;
}

vec3 calc_clouds() {
	return vec3(0.0);
}

vec3 calc_sky(in vec3 sphere, in vec3 vsphere) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	sky += suncolor * smoothstep(0.997, 0.998, abs(dot(vsphere, lightPosition))) * (1.0 - rainStrength);

	return sky;
}

#define CrespecularRays
//#define HIGH_QUALITY_Crespecular
#ifdef CrespecularRays

#ifdef HIGH_QUALITY_Crespecular
const float vl_steps = 48.0;
const int vl_loop = 47;
#else
const float vl_steps = 4.0;
const int vl_loop = 5;
#endif

vec3 VL(in vec3 owpos, in vec3 sunl, in float sunh, in float cdepth) {
	vec3 swpos = owpos;
	vec3 dir = normalize(owpos) * min(shadowDistance, cdepth) / vl_steps;
	float prev = 0.0, total = 0.0;

	for (int i = 0; i < vl_loop; i++) {
		swpos -= dir;
		float dither = bayer_8x8(texcoord + vec2(i) * 0.01, vec2(viewWidth, viewHeight));
		vec3 shadowpos = wpos2shadowpos(swpos + dir * dither);
		float sdepth = texture2D(shadowtex1, shadowpos.xy).x;
		if (shadowpos.z + 0.0006 < sdepth && sdepth < 0.9999) {
			total += (prev + 1.0) * length(dir) * (1 + dither) * 0.5;
			prev = 1.0;
		}
	}

	total = min(total, 512.0);

	return ((total + distance(cdepth, min(shadowDistance, cdepth))) / 512.0) * sqrt(1.0 - sunh) * 0.07 * sunl;
}
#endif


#endif
