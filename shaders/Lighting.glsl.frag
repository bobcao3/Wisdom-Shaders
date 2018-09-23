#ifndef _INCLUDE_LIGHT
#define _INCLUDE_LIGHT

//#include "Material.frag.glsl"
#include "Utilities.glsl.frag"

//==============================================================================
// Definitions
//==============================================================================

struct LightSource {
	vec3 color;
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

float light_mclightmap_attenuation(in float lm) {
	float falloff = 5.0;

	lm = exp(-(1.0 - lm) * falloff);
	lm = max(0.0, lm - exp(-falloff));

	return lm;
}

// #define FAKE_GI_REFLECTION

float light_mclightmap_simulated_GI(in float Ld, in vec3 L, in vec3 N) {
	float simulatedGI = 0.4 * (-1.333 / (3.0 * pow(Ld, 3.0) + 1.0) + 1.333);

	#ifdef FAKE_GI_REFLECTION
	vec3 sunRef = reflect(L, upVec);
	simulatedGI *= 1.5 + 0.5 * max(0.0, dot(sunRef, N));
	#else
	simulatedGI *= 2.0;
	#endif

	return simulatedGI;
}

//==============================================================================
// Shadow Stuff
//==============================================================================

vec3 wpos2shadowpos(in vec3 wpos) {
	vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	shadowposition /= shadowposition.w;

	float distb = length(shadowposition.xy);
	float distortFactor = negShadowBias + distb * SHADOW_MAP_BIAS;
	shadowposition.xy /= distortFactor;

	return shadowposition.xyz * 0.5f + 0.5f;
}

#define SHADOW_FILTER

const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);

float shadowTexSmooth(in sampler2D s, in vec3 spos, in float bias, out float depth) {
	vec2 px0 = vec2(spos.xy + shadowPixSize * vec2(0.25, 0.25));
	depth = 0.0;
	float texel = texture2D(s, px0).x; depth += texel;
	float res1 = float(texel + bias < spos.z);

	vec2 px1 = vec2(spos.xy + shadowPixSize * vec2(0.5, -0.5));
	texel = texture2D(s, px1).x; depth += texel;
	float res2 = float(texel + bias < spos.z);

	vec2 px2 = vec2(spos.xy + shadowPixSize * vec2(-0.5, -0.5));
	texel = texture2D(s, px2).x; depth += texel;
	float res3 = float(texel + bias < spos.z);

	vec2 px3 = vec2(spos.xy + shadowPixSize * vec2(-0.5, 0.5));
	texel = texture2D(s, px3).x; depth += texel;
	float res4 = float(texel + bias < spos.z);
	depth *= 0.25;

	return (res1 + res2 + res3 + res4) * 0.25;
}

#define VARIANCE_SHADOW_MAPS

float light_fetch_shadow(sampler2D smap, in float bias, in vec3 spos, out float thickness) {
	float shade = 0.0; thickness = 0.0;

	if (spos != clamp(spos, vec3(0.0), vec3(1.0))) return shade;

	#ifdef SHADOW_FILTER
		#ifdef VARIANCE_SHADOW_MAPS
		float M1 = 0.0, M2 = 0.0;

		float a = 0.0;
		float xs = 0.0;
		float n = bayer_4x4(texcoord.st, vec2(viewWidth, viewHeight));
		for (int i = -1; i < 2; i++) {
			for (int j = -1; j < 2; j++) {
				vec2 offset = vec2(i, j) * (fract(n + i * j * 0.17) * (1.0 + cloud_coverage * 2.0) * 0.7 + 0.3);
				a = texture2D(smap, spos.st + offset * 0.001f).x + bias * (1.0 + n);
				M2 += a * a;
				M1 += a;

				xs += float(a < spos.z);
			}
		}
		const float d25f = 1.0 / 9.0;
		M1 *= d25f; M2 *= d25f; xs *= d25f;

		if (M1 < spos.z) {
			float t_M1 = spos.z - M1;

			float v = M2 - M1 * M1;
			shade = max(xs, 1.0 - v / (v + t_M1 * t_M1));
		}

		thickness = distance(spos.z, M1) * 64.0 * shade;
		#else
		float avd = 0.0;
		float n = bayer_4x4(texcoord.st, vec2(viewWidth, viewHeight));
		for (int i = -1; i < 2; i++) {
			for (int j = -1; j < 2; j++) {
				vec2 offset = vec2(i, j) * (fract(n + i * j * 0.17) * (1.0 + cloud_coverage * 2.0) * 0.7 + 0.3);
				float shadowDepth = texture2D(smap, spos.st + offset * 0.001f).x + bias * (1.0 + n);
				avd += shadowDepth;
				shade += float(shadowDepth + bias < spos.z);
			}
		}
		shade /= 9.0f; avd /= 9.0f;
		thickness = distance(spos.z, avd) * 64.0 * shade;
		#endif
	#else
		float M1;
		shade = shadowTexSmooth(smap, spos, bias, M1);
		thickness = distance(spos.z, M1) * 64.0 * shade;
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

float light_fetch_shadow_fast(sampler2D smap, in float bias, in vec3 spos) {
	if (spos != clamp(spos, vec3(0.0), vec3(1.0))) return 0.0;

	float shadowDepth = texture2D(smap, spos.st).x;
	float shade = float(shadowDepth + bias < spos.z);
/*
	float edgeX = abs(spos.x) - 0.9f;
	float edgeY = abs(spos.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade = max(0.0, shade);*/

	return shade;
}

float light_shadow_autobias(float l) { return shadowPixSize.x * l * 2.0 + 0.00015; }

//==============================================================================
// PBR Stuff
//==============================================================================

float light_PBR_oren_diffuse(in vec3 v, in vec3 l, in vec3 n, in float r, in float NdotL, in float NdotV) {
	float t = max(NdotL,NdotV);
	float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
	float c = g/t - g*t;

	float a = .285 / (r+.57) + .5;
	float b = .45 * r / (r+.09);

	return Positive(NdotL) * (b * c + a);
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
	float att = oren * Li.light.attenuation;
	vec3 radiance = att * Li.light.color;

	vec3 F0 = vec3(0.02);
	F0 = mix(F0, mat.albedo, mat.metalic);

	vec3 H = normalize(Li.L - mat.nvpos);
	float NDF = DistributionGGX(mat.N, H, mat.roughness);
	float G = GeometrySmith(NdotV, NdotL, mat.roughness);
	vec3 F = light_PBR_fresnelSchlickRoughness(Positive(dot(H, -mat.nvpos)), F0, mat.roughness);

	vec3 nominator = NDF * G * F;
	float denominator = 4 * Positive(NdotV) * Positive(NdotL);
	vec3 specular = nominator / denominator;

	return specular * radiance;
}

vec3 light_calc_PBR_IBL(in vec3 L, Material mat, in vec3 env) {
	vec3 H = normalize(L - mat.nvpos);
	vec3 F0 = vec3(0.02);
	F0 = mix(F0, mat.albedo, mat.metalic);

	vec3 F = light_PBR_fresnelSchlickRoughness(max(dot(H, -mat.nvpos), 0.00001), F0, mat.roughness);

	return (1.0 - mat.roughness) * F * env;
}

//==============================================================================
// Ray Trace (Screen Space Reflection)
//==============================================================================

#define SSR_STEPS 16 // [12 16 20]

vec4 ray_trace_ssr (vec3 direction, vec3 start, float metal) {
	vec3 testPoint = start;
	bool hit = false;
	vec2 uv = vec2(0.0);
	vec4 hitColor = vec4(0.0);

	float h = .02 * length(start);

	for(int i = 0; i < SSR_STEPS; i++) {
		testPoint += direction * h;
		uv = screen_project(testPoint);
		if(clamp(uv, vec2(0.0), vec2(1.0)) != uv) {
			hit = true;
			break;
		}
		float sampleDepth = texture2D(depthtex1, uv).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);

		h = (sampleDepth - testDepth) * (1.0 - 0.0313 * float(i + 1)) * far;

		if(sampleDepth < testDepth + 0.00005 && testDepth - sampleDepth < 0.000976 * (1.0 + testDepth * 200.0 + float(i))){
			float flag = texture2D(gaux1, uv).a;
			if (flag < 0.71f || flag > 0.79f) {
				hitColor.rgb = max(vec3(0.0), texture2DLod(composite, uv, int(metal * 3.0)).rgb);
				hitColor.a = 1.0;
			} else { hitColor.a = 0.0; }

			hit = true;
			break;
		}
	}

	if (!hit) {
		float flag = texture2D(gaux1, uv).a;
		if (flag < 0.71f || flag > 0.79f) {
			hitColor = vec4(max(vec3(0.0), texture2DLod(composite, uv, int(metal * 3.0)).rgb), 0.0);
			hitColor.a = 1.0;
		}
	}

	return hitColor;
}

//==============================================================================
// Light Effects
//==============================================================================
const int Sample_Directions = 6;
const  vec2 ao_offset_table[Sample_Directions + 1] = vec2 [] (
	vec2( 0.0,     1.0    ),
	vec2( 0.7071,  0.7071 ),
	vec2( 0.7071, -0.7071 ),
	vec2( 0.0,    -1.0    ),
	vec2(-0.7071, -0.7071 ),
	vec2(-0.7071,  0.7071 ),
	vec2( 0.0,     1.0    )
);

float calcAO (vec3 cNormal, float cdepth, vec3 vpos, vec2 uv) {
	float radius = 1.02 / cdepth;
	float ao = 0.0;

	float16_t rand = bayer_64x64(uv, vec2(viewWidth, viewHeight));
	for (int i = 0; i < Sample_Directions; i++) {
		rand = fract(rand + 0.13);
		float dx = radius * pow(rand, 2.0);
		vec2 dir = normalize(mix(ao_offset_table[i], ao_offset_table[i + 1], fract(rand + 0.5))) * (dx + pixel * 2.0);

		vec2 h = uv + dir;
		//if (clamp(h, vec2(0.0), vec2(1.0)) != h) continue;
		vec3 nvpos = fetch_vpos(h, depthtex1).xyz;

		float d = length(nvpos - vpos);

		ao += max(0.0, dot(cNormal, nvpos - vpos) / d - 0.15)
		   * max(0.0, - (d * 0.27 - 1.0))
		   * float(d > 0.00001);
	}

	return 1.0 - pow(clamp(ao * 0.265f, 0.0, 1.0), 0.5);
}
#endif
