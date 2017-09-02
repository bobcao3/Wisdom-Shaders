// sea
#define SEA_HEIGHT 0.2 // [0.1 0.2 0.3]

#define NATURAL_WAVE_GENERATOR

#ifdef NATURAL_WAVE_GENERATOR
const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 4;

float16_t sea_octave_micro(f16vec2 uv, float16_t choppy) {
	uv += noise(uv);
	f16vec2 wv = 1.0-abs(sin(uv));
	f16vec2 swv = abs(cos(uv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}
#else
const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 3;

float16_t sea_octave_micro(f16vec2 uv, float16_t choppy) {
	uv += noise(uv);
	return (1.0 - sin(uv.x)) * cos(1.0 - uv.y) * 0.7;
}
#endif
const float16_t SEA_CHOPPY = 4.5;
const float16_t SEA_SPEED = 0.8;
const float16_t SEA_FREQ = 0.12;
const f16mat2 octave_m = f16mat2(1.4,1.1,-1.2,1.4);

const float16_t height_mul[4] = float[4] (
	0.32, 0.24, 0.20, 0.22
);
const float16_t total_height =
  height_mul[0] + 
  height_mul[0] * height_mul[1] +
  height_mul[0] * height_mul[1] * height_mul[2] +
  height_mul[0] * height_mul[1] * height_mul[2] * height_mul[3];
const float16_t rcp_total_height = 1.0 / total_height;

float16_t getwave(vec3 p, in float lod) {
	float16_t freq = SEA_FREQ;
	float16_t amp = SEA_HEIGHT;
	float16_t choppy = SEA_CHOPPY;
	f16vec2 uv = p.xz - vec2(frameTimeCounter * 0.5, 0.0); uv.x *= 0.75;

	float16_t wave_speed = frameTimeCounter * SEA_SPEED;

	float16_t d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY; i++) {
		d = sea_octave_micro((uv+wave_speed)*freq,choppy);
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= -1.1;
		choppy = mix(choppy,1.0,0.2);
	}

	return (h * rcp_total_height) * lod;
}

float16_t getwave2(vec3 p, in float16_t lod) {
	float16_t freq = SEA_FREQ;
	float16_t amp = SEA_HEIGHT;
	float16_t choppy = SEA_CHOPPY;
	f16vec2 uv = p.xz - vec2(frameTimeCounter * 0.5, 0.0); uv.x *= 0.75;

	float16_t wave_speed = frameTimeCounter * SEA_SPEED;

	float16_t d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY2; i++) {
		d = sea_octave_micro((uv+wave_speed)*freq,choppy);
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= -1.1;
		choppy = mix(choppy,1.0,0.2);
	}

	return (h * rcp_total_height) * lod;
}

f16vec3 get_water_normal(in f16vec3 wwpos, in float16_t displacement, in float16_t lod, in f16vec3 dir) {
	f16vec3 w1 = vec3(0.01, dir.y * getwave2(wwpos + vec3(0.01, 0.0, 0.0), lod), 0.0);
	f16vec3 w2 = vec3(0.0, dir.y * getwave2(wwpos + vec3(0.0, 0.0, 0.01), lod), 0.01);
	f16vec3 w0 = displacement * dir;
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

#ifdef WATER_PARALLAX
void WaterParallax(inout vec3 wpos, in float lod) {
	const int maxLayers = 4;
	
	wpos.y -= 1.62;

	vec3 stepin = vec3(0.0);
	vec3 nwpos = normalize(wpos);
	nwpos /= max(0.01, abs(nwpos.y));

	for (int i = 0; i < maxLayers; i++) {
		float h = getwave(wpos + stepin + cameraPosition, lod);

		//if (abs(h - stepin.y) < 0.02) break;

		float diff = stepin.y - h;
		if (isEyeInWater) diff = -diff;
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
	vec3 n = get_water_normal(wpos, w1, 1.0, vec3(0.0, 1.0, 0.0));
	return abs(dot(n, worldLightPosition) * 2.0 - 1.0);
}
#endif
