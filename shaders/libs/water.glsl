// sea
#define SEA_HEIGHT 0.3 // [0.1 0.2 0.3 0.4 0.5]

#define WATER_ITERATIONS 6

#define WATER_PARALLAX

float sea_octave_micro(vec2 fuv, float choppy) {
	fuv += noise(fuv);
	vec2 wv = 1.0-abs(sin(fuv));
	vec2 swv = abs(cos(fuv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}

const float SEA_CHOPPY = 5.5;
const float SEA_SPEED = 5.3;
const float SEA_FREQ = 0.08;
const mat2 octave_m = mat2(1.4,1.1,-1.2,1.4);

const float height_mul[6] = float[6] (
	0.6, 0.4, 0.3, 0.2, 0.1, 0.1
);

uniform float frameTimeCounter;

float getwave(vec3 p, in float lod, int iterations) {
	float freq = SEA_FREQ;
	float amp = 1.0;
	float choppy = SEA_CHOPPY;
	vec2 fuv = p.xz * 2.0 - p.y * 2.0 - frameTimeCounter * vec2(0.1, 0.5); fuv.x *= 0.75;

	float wave_speed = frameTimeCounter * SEA_SPEED;
    float total_height = 1.0;

	float d, h = 0.0;
	for(int i = 0; i < iterations * lod; i++) {
		d = sea_octave_micro((fuv+wave_speed * vec2(0.1, 0.9))*freq,choppy);

        if (i + 1 >= iterations * lod)
        {
            amp *= fract(iterations * lod);
        }

		h += d * amp;
		fuv *= octave_m; freq *= 1.8; amp *= height_mul[i]; //wave_speed *= 0.5;
		choppy = mix(choppy,1.0,0.2);

        total_height += amp;
	}

	return (h / total_height * SEA_HEIGHT - SEA_HEIGHT);
}

float getpeaks(vec3 p, in float lod, int min_iter, int iterations) {
	float freq = SEA_FREQ;
	float16_t amp = 1.0;
	float choppy = SEA_CHOPPY;
	vec2 fuv = p.xz * 2.0 - p.y * 2.0 - frameTimeCounter * vec2(0.1, 0.5); fuv.x *= 0.75;

	float wave_speed = frameTimeCounter * SEA_SPEED;
    float16_t total_height = 1.0;

	float16_t h = float16_t(0.0);
	for(int i = 0; i < iterations * lod; i++) {
		float16_t d = float16_t(sea_octave_micro((fuv+wave_speed * vec2(0.1, 0.9))*freq,choppy));

        if (i + 1 >= iterations * lod)
        {
            amp *= fract(float16_t(iterations * lod));
        }

        if (i >= min_iter)
        {
    		h += smoothstep(float16_t(0.95), float16_t(1.0), d) * amp;
        }
	
    	fuv *= octave_m; freq *= 1.9; amp *= float16_t(height_mul[i]); //wave_speed *= 0.5;
		choppy = mix(choppy,1.0,0.2);

        total_height += amp;
	}

	return float(h / total_height);
}

vec3 get_water_normal(in vec3 wwpos, in float lod, in vec3 N, in vec3 T, in vec3 B) {
	vec3 w1 = 0.002 * T + getwave(wwpos + 0.002 * T, lod, WATER_ITERATIONS) * N;
	vec3 w2 = 0.002 * B + getwave(wwpos + 0.002 * B, lod, WATER_ITERATIONS) * N;
	vec3 w0 = getwave(wwpos, lod, WATER_ITERATIONS) * N;
	return normalize(cross(w2 - w0, w1 - w0));
}

#define WATER_PARALLAX_STEPS 4 // [4 8 16]

#ifdef WATER_PARALLAX
vec3 WaterParallax(vec3 wpos, float lod, vec3 tangentpos) {
	float heightmap = getwave(wpos, lod, WATER_ITERATIONS);

	vec3 offset = vec3(0.0f);
	vec3 s = normalize(tangentpos);
	s /= s.y;

	for (int i = 0; i < WATER_PARALLAX_STEPS; i++) {
		float prev = offset.y;

		offset += (heightmap - prev) * 0.5 * s;

		heightmap = getwave(wpos + vec3(offset.x, 0.0, offset.z), lod, WATER_ITERATIONS);
		if (abs(offset.z - heightmap) < 0.05) break;
	}

	return wpos + offset;
}
#endif

#ifdef WATER_CAUSTICS
float get_caustic (in vec3 wpos) {
	wpos += (64.0 - wpos.y) * (worldLightPosition / worldLightPosition.y);
	vec3 n = get_water_normal(wpos, 1.0, vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0));
	return pow2(1.0 - abs(dot(n, worldLightPosition)));
}
#endif