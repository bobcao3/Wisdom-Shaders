#ifndef _INCLUDE_ATMOS
#define _INCLUDE_ATMOS

#define VECTORS
#define TIME

#include "uniforms.glsl"
#include "transform.glsl"
#include "noise.glsl"

float day = float(worldTime) / 24000.0;
float day_cycle = mix(float(moonPhase), mod(float(moonPhase + 1), 8.0), day) + frameTimeCounter * 0.0001;
float cloud_coverage = max(noise(vec2(day_cycle, 0.0)) * 0.2 + 0.4, rainStrength);

// ============
const float g = .76;
const float g2 = g * g;

const float R0 = 6360e3;
const float Ra = 6420e3;
const float Hr = 8e3;
const float Hm = 1.2e3;

const vec3 I0 = vec3(10.0); // Adjust for D65
const vec3 bR = vec3(3.8e-6, 13.5e-6, 33.1e-6);

#ifdef CLOUDS
#define cloudSteps 8 // [8 16 32]
#endif
const int steps = 6;
const int stepss = 8;

vec3 I = I0; // * (1.0 - cloud_coverage * 0.7);

const vec3 C = vec3(0., -R0, 0.);
const vec3 bM = vec3(21e-6);

float cloud_noise(in vec3 v, float t) {
	float n = 0.0;
	n += 0.55 * (noise(v + t * 0.2) * 2.0 - 1.0);
	n += 0.225 * (noise(v * 2.0 + t * 0.4) * 2.0 - 1.0);
	n += 0.125 * (noise(v * 3.99 + t * 0.6) * 2.0 - 1.0);
	n += 0.0625 * (noise(v * 8.9) * 2.0 - 1.0);
	n += 0.0625 * (noise(v * 16.9) * 2.0 - 1.0);

	return smoothstep(0.0, 0.24, n + 0.55 * (cloud_coverage * 2.0 - 1.0));
}

float cloud(vec3 p) {
	return cloud_noise(p * 0.0003, frameTimeCounter * 0.3) * 40.0;
}

const float cloudAltitude = 4.0e3;
const float cloudDepth = 3.0e3;

void densities(in vec3 pos, out vec2 des) {
	// des.x = Rayleigh
	// des.y = Mie
	float h = max(0.0, length(pos - C) - R0);
	des.x = min(0.5, exp(-h/Hr));

	// Add Ozone layer densities
	des.x += exp(-abs(h - 25e3) /  15e3) * 0.15;

	des.y = exp(-h/Hm);

	if (cloudAltitude - cloudDepth < h && cloudAltitude + cloudDepth > h) {
#ifdef CLOUDS
		float cloud = mix(cloud(pos), rainStrength * 30.0, smoothstep(20e3, 35e3, length(pos)));
#else
		float cloud = max(cloud_coverage - 0.2, 0.0) * 20.0;
#endif
		des.y += cloud * max(0.0, sin(3.1415926 * ((h - cloudAltitude) / cloudDepth * 0.5 + 0.5)));
	}
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
vec4 scatter(vec3 o, vec3 d, vec3 Ds, float lmax, float nseed) {
	if (d.y < 0.0) d.y = 0.0;
	
	float L = min(lmax, escape(o, d, Ra));

#ifdef CLOUDS
	float cloudMaxL = min(lmax, escape(o, d, R0 + cloudAltitude + cloudDepth));
#else
	float cloudMaxL = 0.0;
#endif

	float phaseM, phaseR;
	float phaseM_moon, phaseR_moon;

	{
		float mu = dot(d, Ds);
		float opmu2 = 1. + mu*mu;
		phaseR = .0596831 * opmu2;
		phaseM = .1193662 * (1. - g2) * opmu2;
		phaseM /= ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));		
	}

	{
		float mu = dot(d, -Ds);
		float opmu2 = 1. + mu*mu;
		phaseR_moon = .0596831 * opmu2;
		phaseM_moon = .1193662 * (1. - g2) * opmu2;
		phaseM_moon /= ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));	
	}

	vec2 depth = vec2(0.0);
	vec3 R = vec3(0.), M = vec3(0.);
	vec3 R_moon = vec3(0.), M_moon = vec3(0.);

	float u0 = - (L - cloudMaxL - 1.0) / (1.0 - exp2(steps));

#ifdef CLOUDS
	for (int i = 0; i < steps + cloudSteps; ++i) {
#else
	for (int i = 0; i < steps; ++i) {
#endif
		float dl, l;

#ifdef CLOUDS
		if (i >= cloudSteps)
		{
			dl = u0 * exp2(i + nseed - cloudSteps);
			l = cloudMaxL - u0 * (1.0 - exp2(i + nseed + 1));
		}
		else
		{
			dl = cloudMaxL / float(cloudSteps);
			l = dl * float(i + nseed);
		}
#else
		dl = u0 * exp2(i + nseed);
		l = - u0 * (1.0 - exp2(i + nseed + 1));
#endif

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des *= vec2(dl);
		depth += des;

		float Ls = escape(p, Ds, Ra);
		float u0s = - (Ls - 1.0) / (1.0 - exp2(stepss));

		if (Ls > 0.) {
			vec2 depth_in = vec2(0.0);
			for (int j = 0; j < stepss; ++j) {
				float dls = u0s * exp2(j + nseed);
				float ls = - u0s * (1.0 - exp2(j + nseed + 1));
				vec3 ps = p + Ds * ls;
				vec2 des_in;
				densities(ps, des_in);
				depth_in += des_in * dls;
			}
			depth_in += depth;

			vec3 A = exp(-(bR * depth_in.x + bM * depth_in.y));

			R += A * des.x;
			M += A * des.y;
		}
		
		Ls = escape(p, -Ds, Ra);
		if (Ls > 0.) {
			vec2 depth_in = vec2(0.0);
			for (int j = 0; j < stepss; ++j) {
				float dls = u0s * exp2(j + nseed);
				float ls = - u0s * (1.0 - exp2(j + nseed + 1));
				vec3 ps = p + -Ds * ls;
				vec2 des_in;
				densities(ps, des_in);
				depth_in += des_in * dls;
			}
			depth_in += depth;

			vec3 A = exp(-(bR * depth_in.x + bM * depth_in.y));

			R_moon += A * des.x;
			M_moon += A * des.y;
		}
	}

	vec3 color = I * (max(vec3(0.0), R) * bR * phaseR + max(vec3(0.0), M) * bM * phaseM);
	color += (0.008 * I) * (max(vec3(0.0), R_moon) * bR * phaseR_moon + max(vec3(0.0), M_moon) * bM * phaseM_moon);

	float transmittance = exp(-(bM.x * depth.y));

	return max(vec4(0.0), vec4(color, transmittance));
}

float noisyStarField(vec3 dir)
{
	return max(0.0, hash(dir.xz * sqrt(dir.y)) - 0.995) * 20.0;
}

vec3 starField(vec3 dir)
{
	dir *= 1000.0;
	vec3 uv = floor(dir);
	vec3 t = dir - uv;

	float s000 = noisyStarField(uv);
	float s001 = noisyStarField(uv + vec3(0.0, 0.0, 1.0));
	float s010 = noisyStarField(uv + vec3(0.0, 1.0, 0.0));
	float s011 = noisyStarField(uv + vec3(0.0, 1.0, 1.0));
	float s100 = noisyStarField(uv + vec3(1.0, 0.0, 0.0));
	float s101 = noisyStarField(uv + vec3(1.0, 0.0, 1.0));
	float s110 = noisyStarField(uv + vec3(1.0, 1.0, 0.0));
	float s111 = noisyStarField(uv + vec3(1.0, 1.0, 1.0));

	float s00 = mix(s000, s001, t.z);
	float s01 = mix(s010, s011, t.z);
	float s10 = mix(s100, s101, t.z);
	float s11 = mix(s110, s111, t.z);

	float s0 = mix(s00, s01, t.y);
	float s1 = mix(s10, s11, t.y);

	float star = pow(mix(s0, s1, t.x), 1.5);

	return star * smoothstep(0.0, 500.0, dir.y) * vec3(1.0 - star * 0.8, 1.0, 1.0 + star * 0.8);
}

#endif