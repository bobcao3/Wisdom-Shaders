#include "uniforms.glsl"
#include "vectors.glsl"
#include "noise.glsl"

float day = float(worldTime) / 24000.0;
float day_cycle = mix(float(moonPhase), mod(float(moonPhase + 1), 8.0), day) + frameTimeCounter * 0.0001;
float cloud_coverage = max(noise(vec2(day_cycle, 0.0)) * 0.3, max(rainStrength, wetness));

// ============
const float g = .76;
const float g2 = g * g;

//#define MARS_ATMOSPHERE
#ifdef MARS_ATMOSPHERE
const float R0 = 4389e3;
const float Ra = 4460e3;
float Hr = 10e3;
float Hm = 3.3e3;

const vec3 I0 = vec3(2.6);
const vec3 bR = vec3(33.1e-6, 13.5e-6, 5.8e-6);
#else
const float R0 = 6370e3;
const float Ra = 6425e3;
const float Hr = 10e3;
const float Hm = 2.7e3;

const vec3 I0 = vec3(10.0) / vec3(1.0, 0.8832, 0.7817); // Adjust for D65
const vec3 bR = vec3(5.8e-6, 13.5e-6, 33.1e-6);
#endif

#ifdef AT_LSTEP
const int steps = 4;
const int stepss = 3;
#else
const int steps = 5;
const int stepss = 3;
#endif
vec3 I = I0 * (1.0 - cloud_coverage * 0.7);

const vec3 C = vec3(0., -R0, 0.);
const vec3 bM = vec3(31e-6);

#define CLOUDS_2D

#ifdef CLOUDS_2D
const mat2 octave_c = mat2(1.4,1.2,-1.2,1.4);

float calc_clouds(in vec3 sphere, in vec3 cam) {
	if (sphere.y < 0.0) return 0.0;

	vec3 c = sphere / max(sphere.y, 0.001) * 768.0;
	c += noise((c.xz + cam.xz) * 0.001 + frameTimeCounter * 0.01) * 200.0 / sphere.y;
	vec2 uv = (c.xz + cam.xz);

	uv.x += frameTimeCounter * 10.0;
	uv *= 0.002;
	float n  = noise(uv * vec2(0.5, 1.0)) * 0.5;
		uv += vec2(n * 0.6, 0.0) * octave_c; uv *= 6.0;
		  n += noise(uv) * 0.25;
		uv += vec2(n * 0.4, 0.0) * octave_c + vec2(frameTimeCounter * 0.1, 0.2); uv *= 3.01;
		  n += noise(uv) * 0.105;
		uv += vec2(n, 0.0) * octave_c + vec2(frameTimeCounter * 0.03, 0.1); uv *= 2.02;
		  n += noise(uv) * 0.0625;
	n = smoothstep(0.0, 1.0, n + cloud_coverage);

	n *= smoothstep(0.0, 140.0, sphere.y);

	return n;
}
#endif

void densities(in vec3 pos, out vec2 des) {
	// des.x = Rayleigh
	// des.y = Mie
	float h = length(pos - C) - R0;
	des.x = exp(-h/Hr);

	#ifndef MARS_ATMOSPHERE
	// Add Ozone layer densities
	des.x += exp(-max(0.0, (h - 35e3)) /  5e3) * exp(-max(0.0, (35e3 - h)) / 15e3) * 0.2;
	#endif

	#ifdef AT_LSTEP
	des.y = exp(-h/Hm);
	#else
	des.y = exp(-h/Hm) * (1.0 + cloud_coverage);
	#endif
}

float escape(in vec3 p, in vec3 d, in float R) {
	vec3 v = p - C;
	float b = dot(v, d);
	float c = dot(v, v) - R*R;
	float det2 = b * b - c;
	if (det2 < 0.) return -1.;
	float det = sqrt(det2);
	float t1 = -b - det, t2 = -b + det;
	return (t1 >= 0.) ? t1 : t2;
}

// this can be explained: http://www.scratchapixel.com/lessons/3d-advanced-lessons/simulating-the-colors-of-the-sky/atmospheric-scattering/
vec3 scatter(vec3 o, vec3 d, vec3 Ds, float l) {
	if (d.y < 0.0) d.y = 0.0016 / (-d.y + 0.04) - 0.04;

	float L = min(l, escape(o, d, Ra));
	float mu = dot(d, Ds);
	float opmu2 = 1. + mu*mu;
	float phaseR = .0596831 * opmu2;
	float phaseM = .1193662 * (1. - g2) * opmu2;
	float phaseM_moon = phaseM / ((2. + g2) * pow(1. + g2 + 2.*g*mu, 1.5));
	phaseM /= ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));
	phaseM_moon *= max(0.5, l / 200e3);

	vec2 depth = vec2(0.0);
	vec3 R = vec3(0.), M = vec3(0.);

	float u0 = - (L - 100.0) / (1.0 - exp2(steps));

	float dither = fma(noise(d.xy + d.zz), 0.5, 0.5);

	for (int i = 0; i < steps; ++i) {
		float dl = u0 * exp2(i - dither);
		float l = - u0 * (1.0 - exp2(i - dither + 1));
		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des *= vec2(dl);
		depth += des;

		float Ls = escape(p, Ds, Ra);
		if (Ls > 0.) {
			//float dls = Ls;
			vec2 depth_in = vec2(0.0);
			for (int j = 0; j < stepss; ++j) {
				float ls = float(j) / float(stepss) * Ls;
				vec3 ps = p + Ds * ls;
				vec2 des_in;
				densities(ps, des_in);
				depth_in += des_in;
			}
			depth_in *= vec2(Ls) / float(stepss);
			depth_in += depth;

			vec3 A = exp(-(bR * depth_in.x + bM * depth_in.y));

			R += A * des.x;
			M += A * des.y;
		} else {
			return vec3(0.);
		}
	}

	vec3 color = I * (R * bR * phaseR + M * bM * phaseM + vec3(0.0001, 0.00017, 0.0003) + (0.02 * vec3(0.005, 0.0055, 0.01)) * phaseM_moon * smoothstep(0.05, 0.2, d.y));
	return max(vec3(0.0), color);
}
// ============

float groundFogH(in float d, in float h, in vec3 rayDir) {
	const float b = 1.0;
	const float c = 1.0;
	float y = rayDir.y;
	return clamp(c * exp(-h*b) * (1.0-exp( -y*b ))/y, 0.0, 1.0);
}

float groundFog(in float d, in float h, in vec3 rayDir) {
	const float b = 1.0;
	const float c = 1.0;
	float y = rayDir.y;//sign(rayDir.y) * max(abs(rayDir.y), 0.00002);
	return clamp(c * exp(-h*b) * (1.0-exp( -d*y*b ))/y, 0.0, 1.0);
}

#ifdef CrespecularRays

#ifdef HIGH_QUALITY_Crespecular
const float vl_steps = 24.0;
const int vl_loop = 24;
#else
const float vl_steps = 8.0;
const int vl_loop = 8;
#endif

float VL(vec2 uv, vec3 owpos, out float vl, vec3 wL) {
	vec3 adj_owpos = owpos - vec3(0.0,1.62,0.0);
	float adj_depth = length(adj_owpos);

	vec3 swpos = owpos;
	float step_length = min(shadowDistance * 1.8, adj_depth) / vl_steps;
	vec3 dir = normalize(adj_owpos) * step_length;
	float prev = 1.0, total = 0.0;

	#ifndef BAYER_64
	#define BAYER_64
	float dither = bayer_64x64(uv, vec2(viewWidth, viewHeight));
	bayer_64 = dither;
	#else
	float dither = bayer_64;
	#endif

	for (int i = 0; i < vl_loop; i++) {
		swpos -= dir;
		dither = fract(dither + 0.618);
		vec3 shadowpos = wpos2shadowpos(swpos + dir * dither);

		#ifdef HIGH_LEVEL_SHADER
		float sdepth = texelFetch2D(shadowtex0, ivec2(shadowpos.xy * vec2(shadowMapResolution)), 0).x;
		#else
		float sdepth = texture2D(shadowtex0, shadowpos.xy).x;
		#endif

		float hit = float(shadowpos.z + 0.0006 < sdepth);
		if (shadowpos.x < 0.0 || shadowpos.y < 0.0 || shadowpos.x > 1.0 || shadowpos.y > 1.0 || shadowpos.z < 0.0 || shadowpos.z > 1.0) hit = 1.0;

		#ifdef CLOUD_CRESPECULAR
		hit = min(hit, 1.0 - calc_clouds(wL * 512.0, swpos + dir * dither));
		#endif
	
		total += (prev + hit) * step_length * 0.5;

		prev = hit;
	}

	total = min(total, 512.0);
	vl = total / 512.0f;

	return (max(0.0, adj_depth - shadowDistance) + total) / 768.0f;
}
#endif
