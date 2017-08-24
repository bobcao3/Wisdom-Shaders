#ifndef _INCLUDE_ATMOS
#define _INCLUDE_ATMOS

const vec3 wavelengthRGB = vec3(0.7, 0.5461, 0.4358);
const vec3 skyOriginalRGB = vec3(1.0) / pow(wavelengthRGB, vec3(4.0));
const vec3 skyRGB = skyOriginalRGB / skyOriginalRGB.b;

void calc_fog(in float depth, in float start, in float end, inout vec3 original, in vec3 col) {
	original = mix(col, original, pow(clamp((end - depth) / (end - start), 0.0, 1.0), (1.0 - rainStrength) * 0.5 + 0.5));
}

void calc_fog_height(Material mat, in float16_t start, in float16_t end, inout f16vec3 original, in f16vec3 col) {
	float16_t coeif = 1.0 - clamp((end - mat.cdepth) / (end - start), 0.0, 1.0);
	coeif *= clamp((end - mat.wpos.y) / (end - start), 0.0, 1.0);
	coeif = pow(coeif, (1.0 - rainStrength) * 0.5 + 0.5);
	original = mix(original, col, coeif);
}

f16vec3 mist_color = f16vec3(luma(suncolor) * 0.1);

f16vec3 calc_atmosphere(in f16vec3 sphere, in f16vec3 vsphere) {
	float16_t h = max(normalize(sphere).y, 0.0);
	f16vec3 at = skyRGB;
	
	at = mix(at, f16vec3(0.7), max(0.0, cloud_coverage));
	at *= 1.0 - (0.5 - rainStrength * 0.3) * h;
	
	float16_t h2 = pow(max(0.0, 1.0 - h * 1.4), 2.5);
	at += h2 * mist_color * clamp(length(sphere) / 512.0, 0.0, 1.0) * 3.5;
	
	float16_t VdotS = dot(vsphere, lightPosition);
	VdotS = max(VdotS, 0.0) * (1.0 - extShadow);
	//float lSun = luma(suncolor);
	at = mix(at, suncolor, smoothstep(0.1, 1.0, h2 * pow(VdotS, 2.0)));
	at *= max(0.0, luma(ambient) * 1.2 - 0.02);
	
	at += suncolor * 0.009 * VdotS * (0.7 + cloud_coverage);
	//at += suncolor * 0.011 * pow(VdotS, 4.0) * (0.7 + cloud_coverage);
	at += suncolor * 0.015 * pow(VdotS, 8.0) * (0.7 + cloud_coverage);
	at += suncolor * 0.22 * pow(VdotS, 30.0) * (0.7 + cloud_coverage);
	
	//at += suncolor * 0.3 * pow(VdotS, 4.0) * rainStrength;
	
	return at;
}

const f16mat2 octave_c = f16mat2(1.4,1.2,-1.2,1.4);

f16vec4 calc_clouds(in f16vec3 sphere, in f16vec3 cam, float16_t dotS) {
	if (sphere.y < 0.0) return f16vec4(0.0);

	f16vec3 c = sphere / max(sphere.y, 0.001) * 768.0;
	c += noise((c.xz + cam.xz) * 0.001 + frameTimeCounter * 0.01) * 200.0 / sphere.y;
	f16vec2 uv = (c.xz + cam.xz);
	
	uv.x += frameTimeCounter * 10.0;
	uv *= 0.002;
	uv.y *= 0.75;
	float16_t n  = noise(uv * f16vec2(0.5, 1.0)) * 0.5;
		uv += f16vec2(n * 0.5, 0.3) * octave_c; uv *= 3.0;
		  n += noise(uv) * 0.25;
		uv += f16vec2(n * 0.9, 0.2) * octave_c + f16vec2(frameTimeCounter * 0.1, 0.2); uv *= 3.01;
		  n += noise(uv) * 0.105;
		uv += f16vec2(n * 0.4, 0.1) * octave_c + f16vec2(frameTimeCounter * 0.03, 0.1); uv *= 3.02;
		  n += noise(uv) * 0.0625;
	n = smoothstep(0.0, 1.0, n + cloud_coverage);
	
	n *= smoothstep(0.0, 140.0, sphere.y);
	
	return f16vec4(mist_color + pow(dotS, 3.0) * (1.0 - n) * suncolor * 0.5 * (1.0 - extShadow), 0.5 * n);
}

#define HQ_VOLUMETRICS

#define VOLUMETRIC_CLOUDS
#ifdef VOLUMETRIC_CLOUDS
float16_t cloud_depth_map(f16vec2 uv) {
	float16_t n  = noise(uv * f16vec2(0.5, 1.0)) * 0.5;
	uv += f16vec2(0.5, 0.3) * octave_c; uv *= 3.0;
	 n += noise(uv) * 0.25;
	uv += f16vec2(0.9, 0.2) * octave_c + f16vec2(frameTimeCounter * 0.1, 0.2); uv *= 3.01;
	 n += noise(uv) * 0.105;
	uv += f16vec2(0.4, 0.1) * octave_c + f16vec2(frameTimeCounter * 0.03, 0.1); uv *= 3.02;
	 n += noise(uv) * 0.0625;
	
	return smoothstep(0.0, 0.5, n + cloud_coverage);
}

f16vec4 volumetric_clouds(in f16vec3 sphere, in f16vec3 cam, float16_t dotS) {
	if (sphere.y < -0.1) return f16vec4(0.0);

	sphere.y += 0.1;
	f16vec3 c = sphere / max(sphere.y, 0.001) * 500.0;
	f16vec3 ray = c + cam;
	f16vec3 ray_step = sphere / sphere.y;
	
	float16_t n = 0.0, prev = 0.0;
	float16_t dither = bayer_64x64(texcoord, f16vec2(viewWidth, viewHeight));
	
	float16_t thickness = 0.0;
	f16vec3 H = normalize(worldLightPosition + normalize(sphere));
	for (int i = 0; i < 6; i++) {
		float16_t h = cloud_depth_map(ray.xz * 0.0006);
		
		ray += ray_step * (700.0 - ray.y) * 0.1 * (1.0 + dither);
		dither = fract(dither + 0.6117);
		
		float16_t st = 0.0;
		if (h > 0.0 && ray.y > 600.0 - h * 100.0 && ray.y < 600.0 + h * 100.0) st = 1.0;
		n += (prev + st) * 0.0625;
		prev = st;
		
		// Thickness
		f16vec3 lray = ray + H * 50.0 * (2.0 - dither);
		h = cloud_depth_map(lray.xz * 0.0006);
		if (h > 0.0 && lray.y > 600.0 - h * 100.0 && lray.y < 600.0 + h * 100.0)
			thickness += h;
	}
	
	thickness = smoothstep(0.0, 3.0, thickness);
	n *= 1.1;
	
	return f16vec4(mist_color * (1.5 - thickness * 0.7) + pow(dotS, 3.0) * suncolor * 0.5 * (1.0 - extShadow), max(n - 0.1, 0.0) * smoothstep(0.0, 30.0, sphere.y));
}
#endif

vec3 calc_sky(in vec3 sphere, in vec3 vsphere, in vec3 cam) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	float dotS = dot(vsphere, lightPosition);

	vec4 clouds = calc_clouds(sphere - vec3(0.0, cam.y, 0.0), cam, max(dotS, 0.0));
	sky = mix(sky, clouds.rgb, clouds.a);
	
	#ifdef HQ_VOLUMETRICS
	vec4 VClouds = volumetric_clouds(sphere - vec3(0.0, cam.y, 0.0), cam, max(dotS, 0.0));
	sky = mix(sky, VClouds.rgb, VClouds.a);
	#endif

	return sky;
}

vec3 calc_sky_with_sun(in vec3 sphere, in vec3 vsphere) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	float dotS = dot(vsphere, lightPosition);

	float ground_cover = smoothstep(30.0, 60.0, sphere.y - cameraPosition.y);
	sky += suncolor * smoothstep(0.998, 0.9985, abs(dotS)) * (1.0 - rainStrength) * 5.0 * ground_cover;
	
	vec4 clouds = calc_clouds(sphere - vec3(0.0, cameraPosition.y, 0.0), cameraPosition, max(dotS, 0.0));
	sky = mix(sky, clouds.rgb, clouds.a);
	
	#ifdef VOLUMETRIC_CLOUDS
	vec4 VClouds = volumetric_clouds(sphere - vec3(0.0, cameraPosition.y, 0.0), cameraPosition, max(dotS, 0.0));
	sky = mix(sky, VClouds.rgb, VClouds.a);
	#endif

	return sky;
}

#define CrespecularRays
//#define HIGH_QUALITY_Crespecular
#ifdef CrespecularRays

#ifdef HIGH_QUALITY_Crespecular
const float vl_steps = 48.0;
const int vl_loop = 48;
#else
const float vl_steps = 8.0;
const int vl_loop = 8;
#endif

float VL(in vec3 owpos, out float vl) {
	vec3 adj_owpos = owpos - vec3(0.0,1.62,0.0);
	float adj_depth = length(adj_owpos);

	vec3 swpos = owpos;
	float step_length = min(shadowDistance, adj_depth) / vl_steps;
	vec3 dir = normalize(adj_owpos) * step_length;
	float prev = 0.0, total = 0.0;

	float dither = bayer_16x16(texcoord, vec2(viewWidth, viewHeight));

	for (int i = 0; i < vl_loop; i++) {
		swpos -= dir;
		dither = fract(dither + 0.11);
		vec3 shadowpos = wpos2shadowpos(swpos + dir * dither);
		float sdepth = texture2DLod(shadowtex1, shadowpos.xy, 2).x;
		
		float hit = float(shadowpos.z + 0.0006 < sdepth);
		total += (prev + hit) * step_length * 0.5;
		
		prev = hit;
	}

	total = min(total, 512.0);
	vl = total / 512.0f;

	return (max(0.0, adj_depth - shadowDistance) + total) / 512.0f;
}
#endif


#endif
