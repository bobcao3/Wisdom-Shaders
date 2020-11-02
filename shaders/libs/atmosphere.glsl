#ifndef _INCLUDE_ATMOS
#define _INCLUDE_ATMOS

#define VECTORS
#define TIME

#include "uniforms.glsl"
#include "transform.glsl"
#include "noise.glsl"

float day = float(worldTime) / 24000.0;
float day_cycle = mix(float(moonPhase), mod(float(moonPhase + 1), 8.0), day) + frameTimeCounter * 0.0001;
float cloud_coverage = max(noise(vec2(day_cycle, 0.0)) * 0.05 + 0.45, rainStrength);

// ============
const float g = .76;
const float g2 = g * g;

const float R0 = 6360e3;
const float Ra = 6420e3;
const float Hr = 8e3;
const float Hm = 1.2e3;

const vec3 I0 = 10.0 * vec3(1.0, 0.8794, 0.8267); // Adjust for D65
const vec3 bR = vec3(3.8e-6, 13.5e-6, 33.1e-6) * 0.7;

#define CLOUD_STEPS 6 // [2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32]

const int steps = 6;
const int stepss = 2;

vec3 I = I0; // * (1.0 - cloud_coverage * 0.7);

const vec3 C = vec3(0., -R0, 0.);
const vec3 bM = vec3(21e-6);
const vec3 bMc = vec3(1e-7);

const mat2 octave_c = mat2(1.4,1.2,-1.2,1.4);

#define FBM_STEPS 2 // [1 2 3 4 5 6]
#define FBM_STEPS_3D 1 // [1 2 3 4 5 6]

float cloud_noise(in vec3 v, float t) {
	float n = 0.0;
	float speed = 0.1;
	float amplitude = 1.0;
	float frequency = -3.0;
	float maxAmplitude = 0.0;

	for (int i = 0; i < FBM_STEPS; i++)
	{
		maxAmplitude += amplitude;
		n += (noise(v.xz * vec2(0.75, 1.0))) * amplitude;
		v += vec3(vec2(n * 0.4, n * 0.15) * octave_c, t * 0.2); v *= frequency;
		amplitude *= 0.5;
	}

	for (int i = 0; i < FBM_STEPS_3D; i++)
	{
		maxAmplitude += amplitude;
		n += (noise(v * vec3(0.75, 0.5, 1.0)) * 2.0 - 1.0) * amplitude;
		v += vec3(vec2(n * 0.4, n * 0.15) * octave_c, t * 0.2); v *= frequency;
		amplitude *= 0.5;
	}

	n = n / maxAmplitude;

	return smoothstep(0.0, 0.15 + rainStrength * 0.7, n - 0.9 + cloud_coverage * 1.8);
}

float cloud(vec3 p) {
	return cloud_noise(p * vec3(0.00013, 0.0002, 0.00013), frameTimeCounter * 0.3) * 50.0;
}

const float cloudAltitude = 9.0e3;
const float cloudDepth = 3.0e3;

void densities(in vec3 pos, out vec2 des) {
	// des.x = Rayleigh
	// des.y = Mie
	float h = max(0.0, length(pos - C) - R0);
	des.x = min(0.5, exp(-h/Hr));

	// Add Ozone layer densities
	des.x += exp(-abs(h - 25e3) /  15e3) * 0.15;

	des.y = exp(-h/Hm);
}

float densitiesCloud(in vec3 pos, in vec3 world_offset) {
	float h = max(0.0, length(pos - C) - R0);

	float c = 0.0;

	if (cloudAltitude - cloudDepth < h && cloudAltitude + cloudDepth > h) {
		c = mix(cloud(pos + world_offset), rainStrength * 30.0, smoothstep(30e3, 250e3, length(pos)));
		c *= max(0.0, sin(3.1415926 * ((h - cloudAltitude) / cloudDepth * 0.5 + 0.5)));
	}

	return c;
}

#define CLOUDS_2D

#ifdef CLOUDS_2D
float cloud2d(in vec3 sphere, in vec3 cam) {
	if (sphere.y < 0.0) return 0.0;

	vec3 c = sphere / max(sphere.y, 0.001) * 768.0;
	c += noise((c.xz + cam.xz) * 0.001 + frameTimeCounter * 0.01) * 200.0 / sphere.y;
	vec2 uv = (c.xz + cam.xz);

	uv.x += frameTimeCounter * 10.0;
	uv *= 0.002;
	float n  = noise(uv * vec2(0.5, 1.0)) * 0.5;
		uv += vec2(n * 0.6, 0.0) * octave_c; uv *= 4.0;
		  n += noise(uv) * 0.25;
		uv += vec2(n * 0.4, 0.0) * octave_c + vec2(frameTimeCounter * 0.1, 0.2); uv *= 2.01;
		  n += noise(uv) * 0.105;
		uv += vec2(n, 0.0) * octave_c + vec2(frameTimeCounter * 0.03, 0.1); uv *= 2.02;
		  n += noise(uv) * 0.0625;
	n = smoothstep(0.0, 1.0, n - 0.3 + cloud_coverage);

	n *= smoothstep(0.0, 140.0, sphere.y) * 0.2;

	return n;
}
#endif

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

vec2 densitiesMap(in vec2 uv)
{
	float h = uv.x * (Ra - R0);
	float phi = (uv.y - 0.5) * 3.1415926;

	vec2 depth = vec2(0.0);

	vec3 P = vec3(0.0, h, 0.0);
	vec3 D = vec3(cos(phi), sin(phi), 0.0);

	float Ls = escape(P, D, Ra);
	// float Lground = escape(P, D, R0);

	// if (Lground != -1) Ls = min(Ls, Lground

	float u0s = - (Ls - 1.0) / (1.0 - exp2(10));

	for (int i = 0; i < 20; i++)
	{
		float dls = u0s * exp2(i);
		float ls = - u0s * (1.0 - exp2(i + 1));

		vec3 ps = P + D * ls;
		vec2 des;
		densities(ps, des);
		depth += vec2(des * dls);
	}

	return depth / Ls;
}

vec2 getDensityFromMap(vec3 p, vec3 d)
{
	float h = max(0.0, length(p - C) - R0) / (Ra - R0);

	vec3 down = normalize(p - C);
	vec2 dir = vec2(0.0, dot(d, down));
	dir.x = length(d - down * dir.y);

	float phi = (atan(dir.y / dir.x) / 3.1415926) + 0.5;

	return vec2(texture(gaux4, vec2(h * 0.25, phi * 0.25 + 0.5)).xy);
}

void inScatter(vec3 p, vec3 D, float radius, vec2 depth, vec2 des, float nseed, vec3 world_offset, out vec3 R, out vec3 M)
{
	float Ls = escape(p, D, radius);

	R = vec3(0.0);
	M = vec3(0.0);

	if (Ls > 0.) {
		vec2 depth_in = vec2(getDensityFromMap(p, D)) * Ls;

		depth_in += depth;

		vec3 A = exp(-(bR * depth_in.x + bM * depth_in.y));

		R = A * des.x;
		M = A * des.y;
	}
}

void inScatter(vec3 p, vec3 D, float radius, vec2 depth, vec2 des, float nseed, vec3 world_offset, out vec3 R, out vec3 M, out vec3 Mc)
{
	float Ls = escape(p, D, radius);

	R = vec3(0.0);
	M = vec3(0.0);

	if (Ls > 0.) {
		vec2 depth_in = vec2(getDensityFromMap(p, D)) * Ls;

		float Ls = cloudDepth;//escape(p, D, R0 + cloudAltitude + cloudDepth);
		float u0s = - (Ls - 1.0) / (1.0 - exp2(stepss));
		for (int j = 0; j < stepss; ++j) {
			float dls = u0s * exp2(j + nseed);
			float ls = - u0s * (1.0 - exp2(j + nseed + 1));
			vec3 ps = p + D * ls;
			depth_in.y += densitiesCloud(ps, world_offset) * dls;
		}

		vec3 A0 = exp(-(bR * depth_in.x + bM * depth_in.y));
		
		depth_in += depth;

		vec3 A = exp(-(bR * depth_in.x + bM * depth_in.y));

		R = A * des.x;
		M = A * des.y;
		Mc = (A0 - A) * des.y;
	}
}

// this can be explained: http://www.scratchapixel.com/lessons/3d-advanced-lessons/simulating-the-colors-of-the-sky/atmospheric-scattering/
vec4 scatter(vec3 o, vec3 d, vec3 Ds, float lmax, float nseed, vec3 world_offset) {
	if (d.y < 0.0) d.y = 0.0;
	
	float L = min(lmax, escape(o, d, Ra));

	float cloudMaxL = min(lmax, escape(o, d, R0 + cloudAltitude + cloudDepth));
	float cloudMinL = 0.0;//min(lmax, escape(o, d, R0 + cloudAltitude - cloudDepth));

	float phaseM, phaseR;
	float phaseM_moon, phaseR_moon;

	{
		float mu = dot(d, Ds);
		float opmu2 = 1. + mu*mu;
		phaseR = .0596831 * opmu2;
		phaseM = .1193662 * (1. - g2) * opmu2;
		phaseM /= ((2. + g2) * pow1d5(1. + g2 - 2.*g*mu));		
	}

	{
		float mu = dot(d, -Ds);
		float opmu2 = 1. + mu*mu;
		phaseR_moon = .0596831 * opmu2;
		phaseM_moon = .1193662 * (1. - g2) * opmu2;
		phaseM_moon /= ((2. + g2) * pow1d5(1. + g2 - 2.*g*mu));	
	}

	vec2 depth = vec2(0.0);
	vec3 R = vec3(0.0), M = vec3(0.0), Mc = vec3(0.0);
	vec3 R_moon = vec3(0.0), M_moon = vec3(0.0), Mc_moon = vec3(0.0);

	for (int i = 0; i < CLOUD_STEPS; ++i) {
		float dl, l;

		dl = (cloudMaxL - cloudMinL) / float(CLOUD_STEPS);
		l = cloudMinL + dl * float(i + nseed * 2.0 - 1.0);

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des.y += densitiesCloud(p, world_offset);

		des *= vec2(dl);
		depth += des;

		vec3 Ri, Mi, Mci;
		inScatter(p, Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R += Ri; M += Mi;
		inScatter(p, -Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R_moon += Ri; M_moon += Mi;
	}

	float u0 = - (L - cloudMaxL - 1.0) / (1.0 - exp2(steps));
	for (int i = 0; i < steps; ++i) {
		float dl, l;

		dl = u0 * exp2(i + nseed);
		l = cloudMaxL - u0 * (1.0 - exp2(i + nseed + 1));

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des *= vec2(dl);
		depth += des;

		vec3 Ri, Mi;
		inScatter(p, Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R += Ri; M += Mi;
		inScatter(p, -Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R_moon += Ri; M_moon += Mi;
	}

#ifdef DISABLE_MIE
	vec3 color = I * (max(vec3(0.0), R) * bR * phaseR);
	color += (0.004 * I) * (max(vec3(0.0), R_moon) * bR * phaseR_moon);
#else
	vec3 color = I * (max(vec3(0.0), R) * bR * phaseR + max(vec3(0.0), M) * bM * phaseM + max(vec3(0.0), Mc) * bMc);
	color += (0.004 * I) * (max(vec3(0.0), R_moon) * bR * phaseR_moon + max(vec3(0.0), M_moon) * bM * phaseM_moon + max(vec3(0.0), Mc_moon) * bMc);
#endif

	float transmittance = exp(-(bM.x * depth.y));

	return max(vec4(0.0), vec4(color, transmittance));
}

float scatterTransmittance(vec3 o, vec3 d, vec3 Ds, float lmax, float nseed, vec3 world_offset) {
	if (d.y < 0.0) d.y = 0.0;
	
	float L = min(lmax, escape(o, d, Ra));

	float cloudMaxL = min(lmax, escape(o, d, R0 + cloudAltitude + cloudDepth));
	float cloudMinL = 0.0;//min(lmax, escape(o, d, R0 + cloudAltitude - cloudDepth));

	float depth = 0.0;

	for (int i = 0; i < CLOUD_STEPS; ++i) {
		float dl, l;

		dl = (cloudMaxL - cloudMinL) / float(CLOUD_STEPS);
		l = cloudMinL + dl * float(i + nseed * 2.0 - 1.0);

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des.y += densitiesCloud(p, world_offset);

		depth += des.y * dl;
	}

	float u0 = - (L - cloudMaxL - 1.0) / (1.0 - exp2(steps));
	for (int i = 0; i < steps; ++i) {
		float dl, l;

		dl = u0 * exp2(i + nseed);
		l = cloudMaxL - u0 * (1.0 - exp2(i + nseed + 1));

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		depth += des.y * dl;
	}

	return exp(-(bM.x * depth));
}

vec4 scatterClouds(vec3 o, vec3 d, vec3 Ds, float lmax, float nseed, vec3 world_offset) {
	if (d.y < 0.0) d.y = 0.0;
	
	float L = min(lmax, escape(o, d, Ra));

	float cloudMaxL = min(lmax, escape(o, d, R0 + cloudAltitude + cloudDepth));
	float cloudMinL = min(lmax, escape(o, d, R0 + cloudAltitude - cloudDepth));

	float phaseM, phaseR;
	float phaseM_moon, phaseR_moon;

	{
		float mu = dot(d, Ds);
		float opmu2 = 1. + mu*mu;
		phaseR = .0596831 * opmu2;
		phaseM = .1193662 * (1. - g2) * opmu2;
		phaseM /= ((2. + g2) * pow1d5(1. + g2 - 2.*g*mu));		
	}

	{
		float mu = dot(d, -Ds);
		float opmu2 = 1. + mu*mu;
		phaseR_moon = .0596831 * opmu2;
		phaseM_moon = .1193662 * (1. - g2) * opmu2;
		phaseM_moon /= ((2. + g2) * pow1d5(1. + g2 - 2.*g*mu));	
	}

	vec2 depth = vec2(0.0);
	vec3 R = vec3(0.0), M = vec3(0.0), Mc = vec3(0.0);
	vec3 R_moon = vec3(0.0), M_moon = vec3(0.0), Mc_moon = vec3(0.0);

	// float steps_required = min(CLOUD_STEPS, ceil(cloudMaxL / 2e3));

	for (int i = 0; i < 3; ++i) {
		float dl, l;

		dl = cloudMinL / 3.0;
		l = dl * float(i + nseed * 2.0 - 1.0);

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des *= vec2(dl);
		depth += des;

		vec3 Ri, Mi;
		inScatter(p, Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R += Ri; M += Mi;
		inScatter(p, -Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R_moon += Ri; M_moon += Mi;
	}

	for (int i = 0; i < CLOUD_STEPS; ++i) {
		float dl, l;

		dl = (cloudMaxL - cloudMinL) / float(CLOUD_STEPS);
		l = cloudMinL + dl * float(i + nseed * 2.0 - 1.0);

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des.y += densitiesCloud(p, world_offset);

		des *= vec2(dl);
		depth += des;

		vec3 Ri, Mi, Mci;
		inScatter(p, Ds, Ra, depth, des, nseed, world_offset, Ri, Mi, Mci); R += Ri; M += Mi; Mc += Mci;
		inScatter(p, -Ds, Ra, depth, des, nseed, world_offset, Ri, Mi, Mci); R_moon += Ri; M_moon += Mi; Mc_moon += Mci;
	}

	float u0 = - (L - cloudMaxL - 1.0) / (1.0 - exp2(steps));
	for (int i = 0; i < steps; ++i) {
		float dl, l;

		dl = u0 * exp2(i + nseed);
		l = cloudMaxL - u0 * (1.0 - exp2(i + nseed + 1));

		vec3 p = o + d * l;

		vec2 des;
		densities(p, des);
		des *= vec2(dl);
		depth += des;

		vec3 Ri, Mi;
		inScatter(p, Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R += Ri; M += Mi;
		inScatter(p, -Ds, Ra, depth, des, nseed, world_offset, Ri, Mi); R_moon += Ri; M_moon += Mi;
	}

	vec3 color = I * (max(vec3(0.0), R) * bR * phaseR + max(vec3(0.0), M) * bM * phaseM + max(vec3(0.0), Mc) * bMc);
	color += (0.004 * I) * (max(vec3(0.0), R_moon) * bR * phaseR_moon + max(vec3(0.0), M_moon) * bM * phaseM_moon + max(vec3(0.0), Mc_moon) * bMc);

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

	float star = pow1d5(mix(s0, s1, t.x));

	return star * smoothstep(0.0, 500.0, dir.y) * vec3(1.0 - star * 0.8, 1.0, 1.0 + star * 0.8);
}

#endif