// sea
#define SEA_HEIGHT 0.3 // [0.1 0.2 0.3 0.4 0.5]

#define NATURAL_WAVE_GENERATOR

#ifdef NATURAL_WAVE_GENERATOR
const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 4;

float16_t sea_octave_micro(f16vec2 fuv, float16_t choppy) {
	fuv += noise(fuv);
	f16vec2 wv = 1.0-abs(sin(fuv));
	f16vec2 swv = abs(cos(fuv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}
#else
const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 3;

float16_t sea_octave_micro(f16vec2 fuv, float16_t choppy) {
	fuv += noise(fuv);
	return (1.0 - sin(fuv.x)) * cos(1.0 - fuv.y) * 0.7;
}
#endif
const float16_t SEA_CHOPPY = 4.5;
const float16_t SEA_SPEED = 5.3;
const float16_t SEA_FREQ = 0.14;
const f16mat2 octave_m = f16mat2(1.4,1.1,-1.2,1.4);

const float16_t height_mul[4] = float[4] (
	0.32, 0.24, 0.20, 0.18
);
const float16_t total_height =
  height_mul[0] +
  height_mul[0] * height_mul[1] +
  height_mul[0] * height_mul[1] * height_mul[2] +
  height_mul[0] * height_mul[1] * height_mul[2] * height_mul[3] + 1.0;
const float16_t rcp_total_height = 1.0 / total_height;

float16_t getwave(vec3 p, in float16_t lod) {
	float16_t freq = SEA_FREQ;
	float16_t amp = SEA_HEIGHT;
	float16_t choppy = SEA_CHOPPY;
	f16vec2 fuv = p.xz * 2.0 - frameTimeCounter * vec2(0.1, 0.5); fuv.x *= 0.75;

	float16_t wave_speed = frameTimeCounter * SEA_SPEED;

	float16_t d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY; i++) {
		d = sea_octave_micro((fuv+wave_speed * vec2(0.1, 0.9))*freq,choppy);
		h += d * amp;
		fuv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= 0.5;
		choppy = mix(choppy,1.0,0.2);
	}

	return (h * rcp_total_height - SEA_HEIGHT) * lod;
}

float16_t getwave2(vec3 p, in float16_t lod) {
	float16_t freq = SEA_FREQ;
	float16_t amp = SEA_HEIGHT;
	float16_t choppy = SEA_CHOPPY;
	f16vec2 fuv = p.xz * 2.0 - frameTimeCounter * vec2(0.1, 0.5); fuv.x *= 0.75;

	float16_t wave_speed = frameTimeCounter * SEA_SPEED;

	float16_t d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY2; i++) {
		d = sea_octave_micro((fuv+wave_speed * vec2(0.1, 0.9))*freq,choppy);
		h += d * amp;
		fuv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= 0.5;
		choppy = mix(choppy,1.0,0.2);
	}

	return (h * rcp_total_height - SEA_HEIGHT) * lod;
}

f16vec3 get_water_normal(in f16vec3 wwpos, in float16_t displacement, in float16_t lod, in f16vec3 N, in f16vec3 T, in f16vec3 B) {
	f16vec3 w1 = 0.01 * T + getwave2(wwpos + 0.01 * T, lod) * N;
	f16vec3 w2 = 0.01 * B + getwave2(wwpos + 0.01 * B, lod) * N;
	f16vec3 w0 = displacement * N;
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

#ifdef WATER_PARALLAX
void WaterParallax(inout vec3 wpos, in float lod, in f16vec3 N) {
	const int maxLayers = 4;

	wpos.y -= 1.62;

	vec3 stepin = vec3(0.0);
	vec3 nwpos = normalize(wpos);
	nwpos /= max(0.01, abs(dot(nwpos, abs(N))));

	for (int i = 0; i < maxLayers; i++) {
		float h = getwave(wpos + stepin + cameraPosition, lod);
		if (isEyeInWater == 1) h += SEA_HEIGHT;

		float diff = dot(stepin,abs(N)) - h;
		stepin += nwpos * diff * 0.5;
	}
	wpos += stepin;
	wpos.y += 1.62;
}
#endif

#ifdef WATER_CAUSTICS
float get_caustic (in vec3 wpos) {
	wpos += (64.0 - wpos.y) * (worldLightPosition / worldLightPosition.y);
	float w1 = getwave2(wpos, 1.0);
	vec3 n = get_water_normal(wpos, w1, 1.0, vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0));
	return pow(1.0 - abs(dot(n, worldLightPosition)), 2.0);
}
#endif
