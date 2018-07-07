// sea
#define SEA_HEIGHT 0.3 // [0.1 0.2 0.3 0.4 0.5]

#define NATURAL_WAVE_GENERATOR

#ifdef NATURAL_WAVE_GENERATOR
const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 4;

float sea_octave_micro(vec2 fuv, float choppy) {
	fuv += noise(fuv);
	vec2 wv = 1.0-abs(sin(fuv));
	vec2 swv = abs(cos(fuv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}
#else
const int ITER_GEOMETRY = 3;
const int ITER_GEOMETRY2 = 3;

float sea_octave_micro(vec2 fuv, float choppy) {
	fuv += noise(fuv);
	return (1.0 - sin(fuv.x)) * cos(1.0 - fuv.y) * 0.7;
}
#endif
const float SEA_CHOPPY = 4.5;
const float SEA_SPEED = 5.3;
const float SEA_FREQ = 0.11;
const mat2 octave_m = mat2(1.4,1.1,-1.2,1.4);

const float height_mul[4] = float[4] (
	0.32, 0.34, 0.30, 0.08
);
const float total_height =
  height_mul[0] +
  height_mul[0] * height_mul[1] +
  height_mul[0] * height_mul[1] * height_mul[2] +
  height_mul[0] * height_mul[1] * height_mul[2] * height_mul[3] + 1.0;
const float rcp_total_height = 1.0 / total_height;

float getwave(vec3 p, in float lod) {
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	vec2 fuv = p.xz * 2.0 - frameTimeCounter * vec2(0.1, 0.5); fuv.x *= 0.75;

	float wave_speed = frameTimeCounter * SEA_SPEED;

	float d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY; i++) {
		d = sea_octave_micro((fuv+wave_speed * vec2(0.1, 0.9))*freq,choppy);
		h += d * amp;
		fuv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= 0.5;
		choppy = mix(choppy,1.0,0.2);
	}

	return (h * rcp_total_height - SEA_HEIGHT) * lod;
}

float getwave2(vec3 p, in float lod) {
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	vec2 fuv = p.xz * 2.0 - frameTimeCounter * vec2(0.1, 0.5); fuv.x *= 0.75;

	float wave_speed = frameTimeCounter * SEA_SPEED;

	float d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY2; i++) {
		d = sea_octave_micro((fuv+wave_speed * vec2(0.1, 0.9))*freq,choppy);
		h += d * amp;
		fuv *= octave_m; freq *= 1.9; amp *= height_mul[i]; wave_speed *= 0.5;
		choppy = mix(choppy,1.0,0.2);
	}

	return (h * rcp_total_height - SEA_HEIGHT) * lod;
}

vec3 get_water_normal(in vec3 wwpos, in float displacement, in float lod, in vec3 N, in vec3 T, in vec3 B) {
	vec3 w1 = 0.01 * T + getwave2(wwpos + 0.01 * T, lod) * N;
	vec3 w2 = 0.01 * B + getwave2(wwpos + 0.01 * B, lod) * N;
	vec3 w0 = displacement * N;
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

#ifdef WATER_PARALLAX
void WaterParallax(inout vec3 wpos, in float lod, in vec3 N) {
	const int maxLayers = 4;

	wpos.y -= 1.62;

	vec3 stepin = vec3(0.0);
	vec3 nwpos = normalize(wpos);
	nwpos /= max(0.01, abs(dot(nwpos, abs(N))));

	for (int i = 0; i < maxLayers; i++) {
		float h = getwave(wpos + stepin + cameraPosition, lod);
		h += float(isEyeInWater) * SEA_HEIGHT;

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
	return pow2(1.0 - abs(dot(n, worldLightPosition)));
}
#endif
