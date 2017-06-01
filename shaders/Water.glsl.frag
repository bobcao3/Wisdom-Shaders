// sea
#define SEA_HEIGHT 0.43 // [0.21 0.33 0.43 0.66]

const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 5;
const float SEA_CHOPPY = 4.0;
const float SEA_SPEED = 0.8;
const float SEA_FREQ = 0.12;
const mat2 octave_m = mat2(1.4,1.1,-1.2,1.4);

//#define NATURAL_WAVE_GENERATOR

float sea_octave_micro(vec2 uv, float choppy) {
	uv += noise(uv);
	vec2 wv = 1.0-abs(sin(uv));
	vec2 swv = abs(cos(uv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}

#ifdef NATURAL_WAVE_GENERATOR
#define sea_octave sea_octave_micro
#else
float sea_octave(vec2 uv, float choppy) {
	uv += noise_tex(uv);
	vec2 wv = 1.0-abs(sin(uv));
	vec2 swv = abs(cos(uv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}

#endif

const float height_mul[5] = float[5] (
	0.32, 0.24, 0.18, 0.18, 0.16
);

float getwave(vec3 p) {
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	vec2 uv = p.xz ; uv.x *= 0.75;

	float wave_speed = frameTimeCounter * SEA_SPEED;

	float d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY; i++) {
		d = sea_octave((uv+wave_speed)*freq,choppy) * 2.0;
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= -1.3;
		choppy = mix(choppy,1.0,0.2);
	}

	float lod = pow(1.0 - length(p - cameraPosition) / 512.0, 0.5);

	return (h - SEA_HEIGHT) * lod;
}

float getwave2(vec3 p) {
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	vec2 uv = p.xz ; uv.x *= 0.75;

	float wave_speed = frameTimeCounter * SEA_SPEED;

	float d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY; i++) {
		d = sea_octave((uv+wave_speed)*freq,choppy) * 2.0;
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= -1.3;
		choppy = mix(choppy,1.0,0.2);
	}
	
	for(int i = ITER_GEOMETRY; i < ITER_GEOMETRY2; i++) {
		d = sea_octave_micro((uv+wave_speed)*freq,choppy) * 2.0;
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= -1.3;
		choppy = mix(choppy,1.0,0.2);
	}

	float lod = pow(1.0 - length(p - cameraPosition) / 512.0, 0.5);

	return (h - SEA_HEIGHT) * lod;
}

vec3 get_water_normal(in vec3 wwpos, in vec3 displacement) {
	vec3 w1 = vec3(0.01, getwave2(wwpos + vec3(0.01, 0.0, 0.0)), 0.0);
	vec3 w2 = vec3(0.0, getwave2(wwpos + vec3(0.0, 0.0, 0.01)), 0.01);
	#define w0 displacement
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

#define ENHANCED_WATER
#define WATER_PARALLAX
#ifdef WATER_PARALLAX
void WaterParallax(inout vec3 wpos) {
	const int maxLayers = 4;

	vec3 nwpos = normalize(wpos);
	vec3 fpos = nwpos / max(0.1, abs(nwpos.y));
	float exph = 0.0;
	float hstep = 1.0 / float(maxLayers);

	float h;
	for (int i = 0; i < maxLayers; i++) {
		h = getwave(wpos + cameraPosition);
		hstep = (exph - h) * 0.5;//(0.5 + 0.125 * float(i));

		if (h + 0.02 > exph) break;

		exph -= hstep;
		wpos += vec3(fpos.x, 0.0, fpos.z) * hstep;
	}
	wpos -= vec3(fpos.x, 0.0, fpos.z) * abs(h - exph) * hstep;
}
#endif
