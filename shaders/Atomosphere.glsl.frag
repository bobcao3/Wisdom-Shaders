#ifndef _INCLUDE_ATMOS
#define _INCLUDE_ATMOS

const f16vec3 skyRGB = vec3(0.1502, 0.4056, 1.0);

void calc_fog(in float depth, in float start, in float end, inout vec3 original, in vec3 col) {
	original = mix(col, original, pow(clamp((end - depth) / (end - start), 0.0, 1.0), (1.0 - rainStrength) * 0.5 + 0.5));
}

void calc_fog_height(Material mat, in float16_t start, in float16_t end, inout f16vec3 original, in f16vec3 col) {
	float16_t coeif = 1.0 - clamp((end - mat.cdepth) / (end - start), 0.0, 1.0);
	coeif *= clamp((end - mat.wpos.y) / (end - start), 0.0, 1.0);
	coeif = pow(coeif, (1.0 - rainStrength) * 0.5 + 0.5);
	original = mix(original, col, coeif);
}

const f16vec3 vaporRGB = vec3(0.6) + skyRGB * 0.5;
f16vec3 mist_color = vaporRGB * f16vec3(luma(suncolor) * 0.1);

f16vec3 calc_atmosphere(in f16vec3 sphere, in f16vec3 vsphere) {
	float16_t h = pow(max(normalize(sphere).y, 0.0), 2.0);
	f16vec3 at = skyRGB;

	at = mix(at, f16vec3(0.7), max(0.0, cloud_coverage));
	at *= 1.0 - (0.5 - rainStrength * 0.3) * h;

	float16_t h2 = pow(max(0.0, 1.0 - h * 1.4), 2.0);
	at += h2 * mist_color * clamp(length(sphere) / 512.0, 0.0, 1.0) * 3.5;

	float16_t VdotS = dot(vsphere, lightPosition);
	VdotS = max(VdotS, 0.0) * (1.0 - extShadow);
	//float lSun = luma(suncolor);
	at = mix(at, suncolor + ambient, smoothstep(0.1, 1.0, h2 * pow(VdotS, fma(worldLightPosition.y, 2.0, 1.0))));
	at *= max(0.0, luma(ambient) * 1.2 - 0.02);

	at += suncolor * 0.009 * VdotS * (0.7 + cloud_coverage);
	//at += suncolor * 0.011 * pow(VdotS, 4.0) * (0.7 + cloud_coverage);
	at += suncolor * 0.015 * pow(VdotS, 8.0) * (0.7 + cloud_coverage);
	at += suncolor * 0.22 * pow(VdotS, 30.0) * (0.7 + cloud_coverage);

	//at += suncolor * 0.3 * pow(VdotS, 4.0) * rainStrength;

	at += skyRGB * 0.003;

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

	return f16vec4(mist_color + pow(dotS, 3.0) * (1.0 - n) * suncolor * 0.3 * (1.0 - extShadow), 0.5 * n);
}

#define HQ_VOLUMETRICS

#define VOLUMETRIC_CLOUDS
#ifdef VOLUMETRIC_CLOUDS
float16_t cloud_depth_map(in f16vec2 uv) {
	uv *= 0.001;

	float16_t n  = noise(uv * f16vec2(0.6, 1.0));
	uv += f16vec2(0.5, 0.3); uv *= 2.0; uv = octave_c * uv;
	 n += noise(uv) * 0.5;
	uv += f16vec2(0.9, 0.2) * octave_c + f16vec2(frameTimeCounter * 0.1, 0.2); uv *= 2.01; uv = octave_c * uv;
	 n += noise(uv) * 0.25;
	uv += f16vec2(0.4, 0.1) * octave_c + f16vec2(frameTimeCounter * 0.03, 0.1); uv *= 2.02; uv = octave_c * uv;
	 n += noise(uv) * 0.125;
	uv += f16vec2(0.2, 0.05) * octave_c + f16vec2(frameTimeCounter * 0.01, 0.1); uv *= 2.03;
	 n += noise(uv) * 0.0625;
	uv += f16vec2(0.1, 0.025) * octave_c; uv *= 2.04;
	 n += noise(uv) * 0.03125;

	return clamp((n - 0.2 + cloud_coverage) * 1.4, 0.0, 1.0);
}

const float cloud_min = 400.0;
const float cloud_med = 500.0;
const float cloud_max = 600.0;
const float cloud_half = 100.0;

f16vec4 volumetric_clouds(in f16vec3 sphere, in f16vec3 cam, float16_t dotS) {
	if (sphere.y < -0.1 && cam.y < cloud_min - 1.0) return f16vec4(0.0);

	f16vec4 color = f16vec4(mist_color, 0.0);

	sphere.y += 0.1;
	f16vec3 ray = cam;
	f16vec3 ray_step = normalize(sphere);

	float16_t dither = bayer_64x64(texcoord, vec2(viewWidth, viewHeight));

	for (int i = 0; i < 14; i++) {
		float16_t h = cloud_depth_map(ray.xz);
		float16_t b1 = fma(-h, cloud_half, cloud_med);
		float16_t b2 = fma( h, cloud_half, cloud_med);

		f16vec3 sphere_center = f16vec3(0.0, cloud_med - ray.y, 0.0);
		float16_t dist = abs(dot(ray_step, sphere_center));
		float16_t line_to_dot = distance(ray_step * dist, sphere_center);

		if (h == 0.0) h = -2.0 / 12.0;
		float16_t SDF = min(line_to_dot - cloud_half * h + dist + 6.0 / ray_step.y, 20.0 / ray_step.y);

		SDF = max(SDF, (cloud_min - ray.y) / max(0.001, ray_step.y));

		ray += SDF * ray_step * fma(dither, 0.2, 0.8);

		// Check intersect
		if (h > 0.01 && ray.y > b1 && ray.y < b2) {
			// Step back to intersect
			ray -= (line_to_dot - cloud_half * h + 6.0 / ray_step.y) * ray_step;

			color.a = smoothstep(0.0, 1.0, abs(h));
			break;
		}

		if (ray.y > cloud_max) break;
	}

	if (color.a > 0.0) {
		float16_t sunIllumnation = 1.0 - cloud_depth_map((ray + worldLightPosition * 30.0).xz);
		color.rgb += (0.3 + pow(dotS, 4.0) * 0.7) * suncolor * 0.3 * (1.0 - extShadow) * sunIllumnation * (1.0 - max(cloud_coverage, 0.0));
		color.a = min(1.0, cloud_depth_map((ray + ray_step * 50.0).xz) * 3.0) * smoothstep(0.0, 50.0 * (1.0 + cloud_coverage * 2.0), sphere.y);
		color.rgb *= mix(0.7 + (ray.y - cloud_med) / cloud_half * 0.47 * (clamp(sphere.y / 80.0, 0.0, 0.5) + 0.5), 1.2, max(0.0, cloud_coverage * 1.3));
	}

	return color;
}
#endif

vec3 calc_sky(in vec3 sphere, in vec3 vsphere, in vec3 cam) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	float dotS = dot(vsphere, lightPosition);

	vec4 clouds = calc_clouds(sphere - vec3(0.0, cam.y, 0.0), cam, max(dotS, 0.0));
	sky = mix(sky, clouds.rgb, clouds.a);

	#ifdef VOLUMETRIC_CLOUDS
	#ifdef HQ_VOLUMETRICS
	vec4 VClouds = volumetric_clouds(sphere - vec3(0.0, cam.y, 0.0), cam, max(dotS, 0.0));
	sky = mix(sky, VClouds.rgb, VClouds.a);
	#endif
	#endif

	return sky;
}

vec3 calc_sky_with_sun(in vec3 sphere, in vec3 vsphere) {
	vec3 sky = calc_atmosphere(sphere, vsphere);

	float dotS = dot(vsphere, lightPosition);

	float ground_cover = smoothstep(30.0, 60.0, sphere.y - cameraPosition.y);
	sky += suncolor * smoothstep(0.9992, 0.9995, abs(dotS)) * (1.0 - rainStrength) * 5.0 * ground_cover;

	vec4 clouds = calc_clouds(sphere - vec3(0.0, cameraPosition.y, 0.0), cameraPosition, max(dotS, 0.0));
	sky = mix(sky, clouds.rgb, clouds.a);

	#ifdef VOLUMETRIC_CLOUDS
	vec4 VClouds = texture2D(colortex1, texcoord);
	vec4 VClouds1 = texture2DLod(colortex1, texcoord, 1.0);
	vec4 VClouds2 = texture2DLod(colortex1, texcoord, 2.0);
	VClouds.rgb = VClouds.rgb * 0.35f + VClouds1.rgb * 0.5f + VClouds2.rgb * 0.15f;
	VClouds.a = VClouds1.a;
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
