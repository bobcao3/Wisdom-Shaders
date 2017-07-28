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

float light_mclightmap_attenuation(in float l) {
	float light_distance = clamp((1.0 - pow(l, 4.6)), 0.08, 1.0);
	float max_light = 80.5 * pow(l, 2.0);

	const float light_quadratic = 4.9f;
	const float light_constant1 = 1.09f;
	const float light_constant2 = 1.09f;

	return clamp(light_constant1 / (pow(light_distance, light_quadratic)) - light_constant2, 0.0, max_light);
}

// #define FAKE_GI_REFLECTION

float light_mclightmap_simulated_GI(in float Ld, in vec3 L, in vec3 N) {
	float simulatedGI = 0.4 * (-1.333 / (3.0 * pow(Ld, 4.0) + 1.0) + 1.333);
	
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
	vec2 px0 = vec2(spos.xy + shadowPixSize * vec2(0.5, 0.25));
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
	float shade = 0.0; thickness = 1.0;
	#ifdef SHADOW_FILTER
		#ifdef VARIANCE_SHADOW_MAPS
		float M1 = 0.0, M2 = 0.0;
		
		float a = 0.0;
		float xs = 0.0;
		for (int i = 0; i < 25; i++) {
			float n = bayer_4x4(float(i * 0.001) + texcoord.st, vec2(viewWidth, viewHeight)) * (1.0 + rainStrength * 2.0);
			a = texture2D(smap, spos.st + circle_offsets[i] * 0.004f * n).x + bias * (1.0 + n);
			M2 += a * a;
			M1 += a;
			
			xs += float(a < spos.z);
		}
		const float d25f = 1.0 / 25.0;
		M1 *= d25f; M2 *= d25f; xs *= d25f;
		
		if (M1 < spos.z) {
			float t_M1 = spos.z - M1;

			float v = M2 - M1 * M1;
			shade = max(xs, 1.0 - v / (v + t_M1 * t_M1));
		}
		
		thickness = distance(spos.z, M1) * 64.0 * shade;
		#else
		float avd = 0.0;
		for (int i = 0; i < 25; i++) {
			float shadowDepth = texture2D(smap, spos.st + circle_offsets[i] * 0.0008f * (1.0 + rainStrength * 2.0)).x;
			avd += shadowDepth;
			shade += float(shadowDepth + bias < spos.z);
		}
		shade /= 25.0f; avd / 25.0f;
		thickness = distance(spos.z, avd) * 64.0 * shade;
		#endif
	#else
		float M1;
		shade = shadowTexSmooth(smap, spos, bias, M1);
		thickness = distance(spos.z, M1) * 64.0;
	#endif

	float edgeX = abs(spos.x) - 0.9f;
	float edgeY = abs(spos.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade = max(0.0, shade);
	thickness += smoothstep(0.8, 1.0, max(abs(spos.x), abs(spos.y)));
	thickness = min(1.0, thickness);

	return shade;
}

float light_fetch_shadow_fast(sampler2D smap, in float bias, in vec3 spos) {
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

float lightmap_normals(vec3 vpos, vec3 N, float lm) {
	vec3 tangent = normalize(dFdx(vpos));
	vec3 binormal = normalize(dFdy(vpos));
	vec3 normal = cross(tangent, binormal);
	
	float dither = bayer_16x16(texcoord, vec2(viewWidth, viewHeight)) * 0.2 - 0.1;

	float Lx = dFdx(lm) * 240.0 + dither;
	float Ly = dFdy(lm) * 240.0 + dither;
	
	vec3 TL = normalize(vec3(Lx * tangent + 0.0005 * normal + Ly * binormal));
	
	return clamp(dot(N, TL) * 0.5 + 0.5, 0.1, 1.0);
}

vec3 light_calc_PBR(in LightSourcePBR Li, in Material mat, in float subSurfaceThick) {
	float NdotV = Positive(dot(mat.N, -mat.nvpos));
	float NdotL = Positive(dot(mat.N, Li.L));
	
	float oren = light_PBR_oren_diffuse(-mat.nvpos, Li.L, mat.N, mat.roughness, NdotL, NdotV);
	float att = min(1.0, Li.light.attenuation * oren + max(0.0, pow(1.0 - subSurfaceThick, 3.0) * (0.5 + 0.5 * dot(Li.L, mat.nvpos))));
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
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			hit = true;
			break;
		}
		float sampleDepth = texture2D(depthtex0, uv).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);
		
		h = (sampleDepth - testDepth) * (1.0 - 0.0313 * float(i + 1)) * far;
		
		if(sampleDepth < testDepth + 0.00005 && testDepth - sampleDepth < 0.000976 * (1.0 + testDepth * 200.0 + float(i))){
			float flag = texture2D(gaux1, uv).a;
			if (flag < 0.71f || flag > 0.79f) {
				hitColor.rgb = max(vec3(0.0), texture2DLod(composite, uv, int(metal * 3.0)).rgb);
				hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5)) * 2.0, 5.0), 0.0, 1.0);
			} else { hitColor.a = 0.0; }
			
			hit = true;
			break;
		}
	}
	
	if (!hit) {
		float flag = texture2D(gaux1, uv).a;
		if (flag < 0.71f || flag > 0.79f) {
			hitColor = vec4(max(vec3(0.0), texture2DLod(composite, uv, int(metal * 3.0)).rgb), 0.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0);
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
	float radius = 1.08 / cdepth;
	float ao = 0.0;
	
	for (int i = 0; i < Sample_Directions; i++) {
		float rand = bayer_4x4(uv + i * 0.0017, vec2(viewWidth, viewHeight));
		float dx = radius * pow(rand, 2.0);
		vec2 dir = mix(ao_offset_table[i], ao_offset_table[i + 1], rand) * (dx + pixel * 2.0);
			
		#ifdef HQ_AO
		const int dcount = 2;
		#define multi 0.125f
		#else
		const int dcount = 1;
		#define multi 0.265f
		#endif
		for (int j = 0; j < dcount; j++) {
			vec2 h = uv + dir * float(j + 1) / float(dcount);
			if (h.x < 0.0 || h.x > 1.0 || h.y < 0.0 || h.y > 1.0) continue;
			vec3 nvpos = fetch_vpos(h, depthtex1).xyz;
			
			float d = length(nvpos - vpos);
			
			ao += max(0.0, dot(cNormal, nvpos - vpos) / d - 0.15)
			   * max(0.0, 1.0 - d * 0.27)
			   * float(d > 0.00001);
		}
	}

	return 1.0 - pow(clamp(ao * multi, 0.0, 1.0), 0.25);
}
#endif
