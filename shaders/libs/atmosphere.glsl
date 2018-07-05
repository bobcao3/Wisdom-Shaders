#include "uniforms.glsl"
#include "noise.glsl"

// ============
const float R0 = 6360e3;
const float Ra = 6400e3;
#ifdef AT_LSTEP
const int steps = 8;
const int stepss = 2;
const vec3 I0 = vec3(1.2311, 1.0, 0.8286) * 13.0;

vec3 I = I0;
#else
const int steps = 8;
const int stepss = 4;
const vec3 I0 = vec3(10.0);//vec3(1.2311, 1.0, 0.8286) * 15.0;

vec3 I = I0 * (1.0 - wetness * 0.7);
#endif
const float g = .76;
const float g2 = g * g;
float Hr = 10.0 * 1e3;
float Hm = 1.6 * 1e3;

const vec3 C = vec3(0., -R0, 0.);
const vec3 bM = vec3(21e-6);
const vec3 bR = vec3(5.8e-6, 13.5e-6, 33.1e-6);

#define CLOUDS_2D

#ifdef CLOUDS_2D
const f16mat2 octave_c = f16mat2(1.4,1.2,-1.2,1.4);
float cloud_coverage = wetness;

float16_t calc_clouds(in f16vec3 sphere, in f16vec3 cam) {
	if (sphere.y < 0.0) return 0.0;

	f16vec3 c = sphere / max(sphere.y, 0.001) * 768.0;
	c += noise_tex((c.xz + cam.xz) * 0.001 + frameTimeCounter * 0.01) * 200.0 / sphere.y;
	f16vec2 uv = (c.xz + cam.xz);

	uv.x += frameTimeCounter * 10.0;
	uv *= 0.002;
	float16_t n  = noise_tex(uv * f16vec2(0.5, 1.0)) * 0.5;
		uv += f16vec2(n * 0.6, 0.0) * octave_c; uv *= 6.0;
		  n += noise_tex(uv) * 0.25;
		uv += f16vec2(n * 0.4, 0.0) * octave_c + f16vec2(frameTimeCounter * 0.1, 0.2); uv *= 3.01;
		  n += noise(uv) * 0.105;
		uv += f16vec2(n, 0.0) * octave_c + f16vec2(frameTimeCounter * 0.03, 0.1); uv *= 2.02;
		  n += noise(uv) * 0.0625;
	n = smoothstep(0.0, 1.0, n + cloud_coverage);

	n *= smoothstep(0.0, 140.0, sphere.y);

	return n;
}
#endif

void densities(in vec3 pos, out float rayleigh, out float mie) {
	float h = length(pos - C) - R0;
	rayleigh = exp(-h/Hr);
	#ifdef AT_LSTEP
	mie = exp(-h/Hm);
	#else
	mie = exp(-h/Hm) + wetness * smoothstep(0.8, 1.0, 1.0 - h * 5e-6);
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
	if (d.y < 0.0) d.y = 0.0004 / (-d.y + 0.02) - 0.02;

	float L = min(l, escape(o, d, Ra));
	float mu = dot(d, Ds);
	float opmu2 = 1. + mu*mu;
	float phaseR = .0596831 * opmu2;
	float phaseM = .1193662 * (1. - g2) * opmu2;
	float phaseM_moon = phaseM / ((2. + g2) * pow(1. + g2 + 2.*g*mu, 1.5));
	phaseM /= ((2. + g2) * pow(1. + g2 - 2.*g*mu, 1.5));

	float depthR = 0., depthM = 0.;
	vec3 R = vec3(0.), M = vec3(0.);

	//float dl = L / float(steps);
	float u0 = - (L - 100.0) / (1.0 - exp2(steps));

	for (int i = 0; i < steps; ++i) {
		float dl = u0 * exp2(i);
		float l = - u0 * (1 - exp2(i + 1));//float(i) * dl;
		vec3 p = o + d * l;

		float dR, dM;
		densities(p, dR, dM);
		dR *= dl; dM *= dl;
		depthR += dR;
		depthM += dM;

		float Ls = escape(p, Ds, Ra);
		if (Ls > 0.) {
			float dls = Ls / float(stepss);
			float depthRs = 0., depthMs = 0.;
			for (int j = 0; j < stepss; ++j) {
				float ls = float(j) * dls;
				vec3 ps = p + Ds * ls;
				float dRs, dMs;
				densities(ps, dRs, dMs);
				depthRs += dRs;
				depthMs += dMs;
			}
      depthRs *= dls;
      depthMs *= dls;

			vec3 A = exp(-(bR * (depthRs + depthR) + bM * (depthMs + depthM)));
			R += A * dR;
			M += A * dM;
		} else {
			return vec3(0.);
		}
	}

	return I * (R * bR * phaseR + M * bM * phaseM) + 0.001 + vec3(0.02, 0.035, 0.08) * phaseM_moon * (1.0 - wetness * 0.9);
}
// ============

#ifdef CrespecularRays

#ifdef HIGH_QUALITY_Crespecular
const float vl_steps = 48.0;
const int vl_loop = 48;
#else
const float vl_steps = 8.0;
const int vl_loop = 8;
#endif

float VL(vec2 uv, vec3 owpos, out float vl) {
	vec3 adj_owpos = owpos - vec3(0.0,1.62,0.0);
	float adj_depth = length(adj_owpos);

	vec3 swpos = owpos;
	float step_length = min(shadowDistance, adj_depth) / vl_steps;
	vec3 dir = normalize(adj_owpos) * step_length;
	float prev = 0.0, total = 0.0;

	float dither = bayer_16x16(uv, vec2(viewWidth, viewHeight));

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
		total += (prev + hit) * step_length * 0.5;

		prev = hit;
	}

	total = min(total, 512.0);
	vl = total / 512.0f;

	return (max(0.0, adj_depth - shadowDistance) + total) / 512.0f;
}
#endif
