#ifndef _INCLUDE_LIGHT
#define _INCLUDE_LIGHT

//==============================================================================
// Definitions
//==============================================================================

struct LightSource {
	vec3 color;
	float attenuation;
};

struct LightSourceHarmonics {
	vec3 color0;
	vec3 color1;
	vec3 color2;
	vec3 color3;
	vec3 color4;
	vec3 color5;

	float attenuation;
};

struct LightSourcePBR {
	LightSource light;
	vec3 L;
};

//==============================================================================
// Light calculation - Traditional
//==============================================================================

vec3 light_calc_diffuse(LightSource Li, Material mat) {
	return Li.attenuation * mat.albedo * Li.color;
}

vec3 light_calc_diffuse_harmonics(LightSourceHarmonics Li, Material mat, vec3 N) {
	vec3 x;

	N = normalize(N);

	x  = ( 0.5 * N.x + 0.5) * Li.color1;
	x += (-0.5 * N.x + 0.5) * Li.color2;
	x += ( 0.5 * N.z + 0.5) * Li.color3;
	x += (-0.5 * N.z + 0.5) * Li.color4;
	x += ( 0.5 * N.y + 0.5) * Li.color0;
	x += (-0.5 * N.y + 0.5) * Li.color5;
	x *= 0.3333333;

	return Li.attenuation * mat.albedo * x;
}

float light_mclightmap_attenuation(in float l) {
	float light_distance = smoothstep(0.0, 1.0, clamp((1.0 - pow(l, 3.6)), 0.08, 1.0));
	const float max_light = 100.0;

	const float light_quadratic = 3.0f;
	const float light_constant1 = 1.09f;
	const float light_constant_linear = 0.4;
	const float light_constant2 = 1.29f;

	return clamp(pow(light_constant1 / light_distance, light_quadratic) + l * light_constant_linear - light_constant2, 0.0, max_light);
}

float light_mclightmap_simulated_GI(in float Ld) {
 	return 0.5 * (-1.333 / (3.0 * pow(Ld, 2.0) + 1.0) + 1.333);
}

//==============================================================================
// Shadow Stuff
//==============================================================================

vec3 wpos2shadowpos(in vec3 wpos) {
	vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	shadowposition /= shadowposition.w;

	float distb = length(shadowposition.xy);
	float distortFactor = negShadowBias + distb * 0.9;
	shadowposition.xy /= distortFactor;

	shadowposition.z *= 0.5;

	return shadowposition.xyz * 0.5f + 0.5f;
}

#define SHADOW_FILTER

const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);

float shadowTexSmooth(in sampler2D s, in vec3 spos, out float depth) {
	vec2 px0 = vec2(spos.xy + shadowPixSize * poisson_4[0]);
	depth = 0.0;
	float texel = texture2D(s, px0).x; depth += texel;
	float res1 = float(texel < spos.z);

	vec2 px1 = vec2(spos.xy + shadowPixSize * poisson_4[1]);
	texel = texture2D(s, px1).x; depth += texel;
	float res2 = float(texel < spos.z);

	vec2 px2 = vec2(spos.xy + shadowPixSize * poisson_4[2]);
	texel = texture2D(s, px2).x; depth += texel;
	float res3 = float(texel < spos.z);

	vec2 px3 = vec2(spos.xy + shadowPixSize * poisson_4[3]);
	texel = texture2D(s, px3).x; depth += texel;
	float res4 = float(texel < spos.z);
	depth *= 0.25;

	return (res1 + res2 + res3 + res4) * 0.25;
}

#define VARIANCE_SHADOW_MAPS

float light_fetch_shadow(in sampler2D smap, in vec3 spos, out float thickness) {
	float shade = 0.0; thickness = 0.0;

	if (spos != clamp(spos, vec3(0.0), vec3(1.0))) return shade;
	
	const float bias_pix = 0.5 / shadowMapResolution;
	float bias = length(spos.xy) * bias_pix;

	#ifdef SHADOW_FILTER
		#ifdef VARIANCE_SHADOW_MAPS
		float M1 = 0.0, M2 = 0.0;

		float a = 0.0;
		float xs = 0.0;

		for (int i = 0; i < 12; i++) {
			a = texture2D(smap, poisson_12[i] * shadowPixSize + spos.st).x + bias;
			M2 += a * a;
			M1 += a;

			xs += float(a < spos.z);
		}
		const float r_12 = 1.0 / 12.0f;
		M1 *= r_12; M2 *= r_12; xs *= r_12;

		if (M1 < spos.z) {
			float t_M1 = spos.z - M1;

			float v = M2 - M1 * M1;
			shade = max(xs, 1.0 - v / (v + t_M1 * t_M1));
		}

		thickness = distance(spos.z, M1) * 256.0 * shade;
		#else
		float avd = 0.0;
		for (int i = 0; i < 12; i++) {
			float shadowDepth = texture2D(smap, poisson_12[i] * shadowPixSize + spos.st).x + bias;
			avd += shadowDepth;
			shade += float(shadowDepth < spos.z);
		}
		const float r_12 = 1.0 / 12.0f;
		shade *= r_12; avd *= r_12;
		thickness = distance(spos.z, avd) * 256.0 * shade;
		#endif
	#else
		float M1;
		shade = shadowTexSmooth(smap, spos, M1);
		thickness = distance(spos.z, M1) * 256.0 * shade;
	#endif

	/*float edgeX = abs(spos.x) - 0.9f;
	float edgeY = abs(spos.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade = max(0.0, shade);*/
	thickness *= 1.0 - smoothstep(0.8, 1.0, max(abs(spos.x), abs(spos.y)));
	thickness = clamp(thickness, 0.0, 1.0);

	return shade;
}

float light_fetch_shadow_fast(sampler2D smap, in vec3 spos) {
	if (spos != clamp(spos, vec3(0.0), vec3(1.0))) return 0.0;

	float shadowDepth = texture2D(smap, spos.st).x;
	float shade = float(shadowDepth < spos.z);
/*
	float edgeX = abs(spos.x) - 0.9f;
	float edgeY = abs(spos.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade = max(0.0, shade);*/

	return shade;
}

//==============================================================================
// PBR Stuff
//==============================================================================

float light_PBR_oren_diffuse(in vec3 v, in vec3 l, in vec3 n, in float r, in float NdotL, in float NdotV) {
	float t = max(NdotL,NdotV);
	float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
	float c = g/t - g*t;

	float a = .285 / (r+.57) + .5;
	float b = .45 * r / (r+.09);

	return NdotL * (b * c + a);
}

vec3 light_PBR_fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

#define GeometrySchlickGGX(NdotV, k) (NdotV / (NdotV * (1.0 - k) + k))

float GeometrySmith(float NdotV, float NdotL, float k) {
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
	float a      = roughness*roughness;
	float a2     = a*a;
	float NdotH  = Positive(dot(N, H));

	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom;

	return a2 / denom;
}

#ifdef DIRECTIONAL_LIGHTMAP
float lightmap_normals(vec3 N, float lm, vec3 tangent, vec3 binormal, vec3 normal) {
	if (lm < 0.0001 || lm > 0.98) return 1.0;

	//float dither = bayer_64x64(uv, vec2(viewWidth, viewHeight)) * 0.1 - 0.05;

	float Lx = dFdx(lm) * 120.0;// + dither;
	float Ly = dFdy(lm) * 120.0;// - dither;

	vec3 TL = normalize(vec3(Lx * tangent + 0.0005 * normal + Ly * binormal));

	return clamp(dot(N, TL) * 0.5 + 0.5, 0.1, 1.0);
}
#endif

vec3 light_calc_PBR(in LightSourcePBR Li, in Material mat, in float subSurfaceThick) {
	float NdotV = Positive(dot(mat.N, -mat.nvpos));
	float NdotL = Positive(dot(mat.N, Li.L));

	float oren = light_PBR_oren_diffuse(-mat.nvpos, Li.L, mat.N, mat.roughness, NdotL, NdotV);
	float att = max(0.0, Li.light.attenuation * oren);
	att += 0.9 * (1.0 - att) * max(0.0, pow(1.0 - subSurfaceThick, 3.0) * (0.5 + 0.5 * dot(Li.L, mat.nvpos)));
	vec3 radiance = att * Li.light.color;

	vec3 F0 = vec3(0.01);
	F0 = mix(F0, mat.albedo, mat.metalic);

	vec3 H = normalize(Li.L - mat.nvpos);
	float NDF = DistributionGGX(mat.N, H, mat.roughness);
	float G = GeometrySmith(NdotV, NdotL, mat.roughness);
	vec3 F = light_PBR_fresnelSchlickRoughness(Positive(dot(H, -mat.nvpos)), F0, mat.roughness);

	vec3 kD = max(vec3(0.0), vec3(1.0) - F);
	kD *= 1.0 - mat.metalic;

	vec3 nominator = NDF * G * F;
	float denominator =  4 * NdotV * NdotL + 0.001;
	vec3 specular = nominator / denominator;

	return (kD / PI * mat.albedo + specular) * radiance;
}

vec3 light_calc_PBR_brdf(LightSourcePBR Li, Material mat) {
	float NdotV = Positive(dot(mat.N, -mat.nvpos));
	float NdotL = Positive(dot(mat.N, Li.L));

	float oren = light_PBR_oren_diffuse(-mat.nvpos, Li.L, mat.N, mat.roughness, NdotL, NdotV);
	vec3 radiance = max(0.0, Li.light.attenuation * oren) * Li.light.color;

	vec3 F0 = vec3(0.01);
	F0 = mix(F0, mat.albedo, mat.metalic);

	vec3 H = normalize(Li.L - mat.nvpos);
	float NDF = DistributionGGX(mat.N, H, mat.roughness);
	float G = GeometrySmith(NdotV, NdotL, mat.roughness);
	vec3 F = light_PBR_fresnelSchlickRoughness(Positive(dot(H, -mat.nvpos)), F0, mat.roughness);

	vec3 nominator = NDF * G * F;
	float denominator =  4 * NdotV * NdotL + 0.001;
	vec3 specular = nominator / denominator;

	return specular * radiance;
}

vec3 light_calc_PBR_IBL(in vec3 color, in vec3 L, Material mat, in vec3
env) {
	vec3 H = normalize(L - mat.nvpos);
	vec3 F0 = vec3(0.02);
	F0 = mix(F0, mat.albedo, mat.metalic);

	vec3 F = light_PBR_fresnelSchlickRoughness(max(dot(H, -mat.nvpos), 0.00001), F0, mat.roughness);

	return mix(color, env, (1.0 - mat.roughness) * F);
}

//==============================================================================
// Ray Trace (Screen Space Reflection)
//==============================================================================

#define SSR_STEPS 20 // [16 20 32]

vec4 ray_trace_ssr (vec3 direction, vec3 start, float metal, sampler2D colorbuf, vec3 N) {
	vec3 testPoint = start;
	bool hit = false;
	vec2 uv = vec2(0.0);
	vec4 hitColor = vec4(0.0);

	float h = 0.1;
	bool bi = false;
	float bayer = bayer_64x64(uv, vec2(viewWidth, viewHeight)) * 0.5;

	float sampleDepth = 0.1;
	float testDepth = far;

	for(int i = 0; i < SSR_STEPS; i++) {
		testPoint += direction * h * (0.75 + bayer);
		bayer = fract(bayer + 0.618);
		uv = screen_project(testPoint);
		if(clamp(uv, vec2(0.0), vec2(1.0)) != uv) {
			hit = true;
			break;
		}
		sampleDepth = texture2D(depthtex1, uv).x;
		sampleDepth = linearizeDepth(sampleDepth);
		testDepth = getLinearDepthOfViewCoord(testPoint);

		if (!bi) bi = sampleDepth < testDepth + 0.005;

		if (bi) {
			h = far * (sampleDepth - testDepth) * 0.618;
		} else {
			h *= 2.2;
		}

		if(sampleDepth < testDepth + 0.00005 && testDepth - sampleDepth < 0.000976 * (1.0 + testDepth * 100.0)){
			hitColor.rgb = max(vec3(0.0), texture2DLod(colorbuf, uv, int(metal * 3.0)).rgb);
			hitColor.a = 1.0;

			hit = true;
			break;
		}
	}

	if (!hit && (clamp(uv, vec2(0.0), vec2(1.0)) == uv)) {
		hitColor.rgb = max(vec3(0.0), texture2DLod(colorbuf, uv, int(metal * 3.0)).rgb);
		hitColor.a = clamp((sampleDepth - testDepth) * far * 0.2, 0.0, 1.0);
	}

	return hitColor;
}

//==============================================================================
// Light Effects
//==============================================================================
#ifdef WAO_HIGH
const int Sample_Directions = 12;
#define ao_offset_table poisson_12
#else
const int Sample_Directions = 4;
#define ao_offset_table poisson_4
#endif
const float rsam = 2.0 / float16_t(Sample_Directions);

float calcAO (vec3 cNormal, float cdepth, vec3 vpos, f16vec2 uv) {
	float16_t radius = 1.0 / cdepth;
	float16_t ao = 0.0;

	float16_t rand = bayer_64x64(uv, f16vec2(viewWidth, viewHeight));
	for (int i = 0; i < Sample_Directions; i++) {
		rand = fract(rand + 0.618);
		float16_t dx = radius * pow(rand, 2.0);
		f16vec2 dir = ao_offset_table[i] * (dx + pixel * 2.0);

		f16vec2 h = uv + dir;
		f16vec3 nvpos = fetch_vpos(h, depthtex1).xyz;

		float d = length(nvpos - vpos) + 0.00001;

		ao += max(0.0, dot(cNormal, nvpos - vpos) / d - 0.15)
		   * max(0.0, - (d * 0.27 - 1.0));
	}

	return 1.0 - sqrt(clamp(ao * rsam, 0.0, 1.0));
}
#endif
