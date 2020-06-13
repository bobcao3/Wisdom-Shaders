#define VECTORS
#define TIME

#include "uniforms.glsl"
#include "noise.glsl"

float day = float(worldTime) / 24000.0;
float day_cycle = mix(float(moonPhase), mod(float(moonPhase + 1), 8.0), day) + frameTimeCounter * 0.0001;
float cloud_coverage = max(noise(vec2(day_cycle, 0.0)) * 0.3, max(rainStrength, wetness));

// ============
const float g = .76;
const float g2 = g * g;

const float R0 = 6370e3;
const float Ra = 6425e3;
const float Hr = 16e3;
const float Hm = 3.6e3;

const vec3 I0 = vec3(10.0) / vec3(1.0, 0.8832, 0.7817); // Adjust for D65
const vec3 bR = vec3(5.8e-6, 13.5e-6, 33.1e-6);

const int steps = 6;
const int stepss = 10;

vec3 I = I0 * (1.0 - cloud_coverage * 0.7);

const vec3 C = vec3(0., -R0, 0.);
const vec3 bM = vec3(31e-6);

void densities(in vec3 pos, out vec2 des) {
	// des.x = Rayleigh
	// des.y = Mie
	float h = length(pos - C) - R0;
	des.x = exp(-h/Hr);

	// Add Ozone layer densities
	des.y += exp(-abs(h - 35e3) /  15e3) * 0.3;

	des.y = exp(-h/Hm) * (1.0 + cloud_coverage);
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