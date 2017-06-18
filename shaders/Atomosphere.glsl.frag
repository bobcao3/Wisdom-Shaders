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
	float h = max(normalize(sphere).y, 0.0);
	vec3 at = vec3(skyRGB * (1.0 - 0.6 * pow(h, 0.75))) * 0.8;
	
	vec3 rain = at;
	calc_fog(length(sphere), 1.0, 512.0, rain, vec3(0.3));
	at = mix(at, rain, rainStrength * 0.8);
	
	float h2 = pow(max(0.0, 1.0 - h * 1.4), 3.0);
	at += h2 * vec3(0.7) * clamp(length(sphere) / 512.0, 0.0, 1.0);
	
	float VdotS = dot(vsphere, lightPosition);
	VdotS = max(VdotS, 0.0) * pow(1.0 - extShadow, 0.33);
	//float lSun = luma(suncolor);
	at = mix(at, suncolor, smoothstep(0.1, 1.0, h2 * pow(VdotS, 3.0)));
	at *= luma(ambient);
	
	at += suncolor * 0.009 * VdotS;
	at += suncolor * 0.011 * pow(VdotS, 4.0);
	at += suncolor * 0.025 * pow(VdotS, 8.0);
	at += suncolor * 0.22 * pow(VdotS, 30.0);
	
	at += suncolor * 0.3 * pow(VdotS, 4.0) * rainStrength;
	
	return at;
}

const mat2 octave_c = mat2(1.4,1.2,-1.2,1.4);

vec4 calc_clouds(in vec3 sphere, float dotS) {
	if (sphere.y < 40.0) return vec4(0.0);

	sphere.y -= cameraPosition.y;
	vec3 c = sphere / sphere.y * 768.0;
	vec2 uv = (c.xz + cameraPosition.xz);
	
	uv.x += frameTimeCounter * 10.0;
	uv *= 0.002;
	uv.y *= 0.75;
	float n  = noise_tex(uv * vec2(0.5, 1.0)) * 0.5;
		uv += vec2(n * 0.5, 0.3) * octave_c; uv *= 3.0;
		  n += noise_tex(uv) * 0.35;
		uv += vec2(n * 0.9, 0.2) * octave_c + vec2(frameTimeCounter * 0.1, 0.2); uv *= 3.01;
		  n += noise_tex(uv) * 0.105;
		uv += vec2(n * 0.4, 0.1) * octave_c + vec2(frameTimeCounter * 0.03, 0.1); uv *= 3.02;
		  n += noise_tex(uv) * 0.0625;
	n = smoothstep(0.0, 1.0, n + rainStrength * 0.6);
	
	vec3 mist_color = vec3(luma(suncolor) * 0.1);
	mist_color += pow(dotS, 4.0) * (1.0 - n) * suncolor * 0.3;
	
	n *= smoothstep(40.0, 80.0, sphere.y);
	
	return vec4(mist_color, 0.5 * n);
}

vec3 calc_sky(in vec3 sphere, in vec3 vsphere) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	float dotS = dot(vsphere, lightPosition);

	vec4 clouds = calc_clouds(sphere, max(dotS, 0.0));
	sky = mix(sky, clouds.rgb, clouds.a);

	return sky;
}

vec3 calc_sky_with_sun(in vec3 sphere, in vec3 vsphere) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	float dotS = dot(vsphere, lightPosition);

	float ground_cover = smoothstep(70.0, 100.0, sphere.y);
	sky += suncolor * smoothstep(0.997, 0.998, abs(dotS)) * (1.0 - rainStrength) * 5.0 * ground_cover;
	
	vec4 clouds = calc_clouds(sphere, max(dotS, 0.0));
	sky = mix(sky, clouds.rgb, clouds.a);

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

float VL(in vec3 owpos, in float cdepth, out float vl) {
	vec3 swpos = owpos;
	vec3 dir = normalize(owpos) * min(shadowDistance, cdepth) / vl_steps;
	float prev = 0.0, total = 0.0;

	for (int i = 0; i < vl_loop; i++) {
		swpos -= dir;
		float dither = bayer_16x16(texcoord + vec2(i) * 0.01, vec2(viewWidth, viewHeight));
		vec3 shadowpos = wpos2shadowpos(swpos + dir * dither);
		float sdepth = texture2D(shadowtex1, shadowpos.xy).x;
		if (shadowpos.z + 0.0006 < sdepth && sdepth < 0.9999) {
			total += (prev + 1.0) * length(dir) * (1 + dither) * 0.5;
			prev = 1.0;
		}
	}

	total = min(total, 512.0);
	vl = total / 512.0f;

	return (max(0.0, cdepth - shadowDistance) + total) / 512.0f;
}
#endif


#endif
