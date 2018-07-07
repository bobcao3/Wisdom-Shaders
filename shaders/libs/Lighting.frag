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
 	return 0.5 * (-1.333 / (3.0 * pow2(Ld) + 1.0) + 1.333);
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

	shadowposition.z = shadowposition.z * 0.5 + 0.25;

	return shadowposition.xyz * 0.5f + 0.5f;
}

//#define SHADOW_FILTER

const vec2 shadowPixSize = vec2(1.0 / shadowMapResolution);

float shadowTexSmooth(in sampler2D s, in vec3 spos, out float depth, in float bias) {
	vec2 uv = spos.xy * vec2(shadowMapResolution) - 1.0;
	vec2 iuv = floor(uv);
	vec2 fuv = uv - iuv;

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x) * 0.75;
    float h1x = h1(fuv.x) * 0.75;
    float h0y = h0(fuv.y) * 0.75;
    float h1y = h1(fuv.y) * 0.75;

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) + 0.5) * shadowPixSize;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) + 0.5) * shadowPixSize;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) + 0.5) * shadowPixSize;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) + 0.5) * shadowPixSize;

	depth = 0.0;
	float texel = texture2D(s, p0).x; depth += texel;
	float res0 = float(texel + bias < spos.z);

	texel = texture2D(s, p1).x; depth += texel;
	float res1 = float(texel + bias < spos.z);

	texel = texture2D(s, p2).x; depth += texel;
	float res2 = float(texel + bias < spos.z);

	texel = texture2D(s, p3).x; depth += texel;
	float res3 = float(texel + bias < spos.z);
	depth *= 0.25;

    return g0(fuv.y) * (g0x * res0  +
                        g1x * res1) +
           g1(fuv.y) * (g0x * res2  +
                        g1x * res3);
}

#define SHADOW_COLOR

#ifdef SHADOW_COLOR
uniform sampler2D shadowcolor0;

vec3 shadowColorSmooth(in sampler2D s, in vec2 spos) {
	vec2 uv = spos * vec2(shadowMapResolution) - 1.0;
	vec2 iuv = floor(uv);
	vec2 fuv = uv - iuv;

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) + 0.5) * shadowPixSize;
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) + 0.5) * shadowPixSize;
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) + 0.5) * shadowPixSize;
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) + 0.5) * shadowPixSize;

	vec3 res0 = texture2D(s, p0).rgb;
	vec3 res1 = texture2D(s, p0).rgb;
	vec3 res2 = texture2D(s, p0).rgb;
	vec3 res3 = texture2D(s, p0).rgb;

    return g0(fuv.y) * (g0x * res0  +
                        g1x * res1) +
           g1(fuv.y) * (g0x * res2  +
                        g1x * res3);
}
#endif

float light_fetch_shadow(in sampler2D smap, in vec3 spos, out float thickness, out vec3 color, float pix_bias) {
	float shade = 0.0; thickness = 0.0;
	color = vec3(1.0);

	if (spos != clamp(spos, vec3(0.0), vec3(1.0))) return shade;
	
	const float bias_pix = 0.2 / 256.0;
	vec2 bias_offcenter = spos.xy * 2.0 - 1.0;
	float bias = dot(bias_offcenter, bias_offcenter) * bias_pix + shadowPixSize.x * pix_bias;

	#ifdef SHADOW_FILTER
	#else
		float M1;
		shade = shadowTexSmooth(smap, spos, M1, bias);
		thickness = distance(spos.z, M1) * 256.0;

		#ifdef SHADOW_COLOR
		float M2 = texture2D(shadowtex0, spos.xy).x;
		if (M2 + bias < M1) color = mix(color, shadowColorSmooth(shadowcolor0, spos.xy), 0.8);
		#endif
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

#ifdef GI
uniform sampler2D shadowcolor1;

mat2 rotate(float rad) {
    float c = cos(rad);
    float s = sin(rad);
    return mat2(c, -s, s, c);
}

vec3 calcGI(sampler2D smap, sampler2D smapColor, in vec3 spos, in vec3 wNorm) {
	if (spos != clamp(spos, vec3(0.0), vec3(1.0))) return vec3(0.0);

	spos.z = (spos.z - 0.25) * 2.0;
	
	vec3 color = vec3(0.0);
	float dither = bayer_64x64(uv, vec2(viewWidth, viewHeight));
	float ang = dither * 3.1415926 * 2.0;

	const float scale = 9.0 / shadowDistance;
	vec2 circleDistribution = rotate(ang) * vec2(scale);
	//if (circleDistribution.y < 0.0) circleDistribution.y *= 3.0;

	vec3 snorm = normalize(mat3(shadowProjection) * (mat3(shadowModelView) * wNorm));

	float fade_dist = distance(spos.xy, vec2(0.5));
	if (fade_dist > 0.6) return vec3(0.0);
	fade_dist = smoothstep(0.0, 0.6, 0.6 - fade_dist);

	const float inv8 = 1.0 / 8.0;
	const float bias = 1.0 / shadowDistance;
	const float attenuation = shadowDistance * shadowDistance * 0.09;

	for (int i = 1; i < 12; i++) {
		vec2 uv = circleDistribution * pow2(i * inv8) + spos.st;
		float shadowDepth = (texture2D(smap, uv).x - 0.25) * 2.0 - bias;
		vec3 soffset = vec3(uv, shadowDepth) - spos;
		float sdist = dot(soffset, soffset);
		vec3 nsoffset = soffset / sqrt(sdist);

		vec3 nsample = texture2D(shadowcolor1, uv).xyz * 2.0 - 1.0;

		float factor = max(dot(nsoffset, snorm) - 0.1, 0.0) * max(dot(-nsoffset, nsample) - 0.1, 0.0);

		if (factor > 0.0)
			color += fromGamma(texture2D(smapColor, uv).rgb) * factor / (1.0 + sdist * attenuation);
	}
	
	color *= fade_dist;

	return color * inv8;
}
#endif

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

vec3 light_calc_PBR(in LightSourcePBR Li, in Material mat, in float subSurfaceThick, bool thin_sublayer_mask) {
	float NdotV = Positive(dot(mat.N, -mat.nvpos));
	float NdotL = Positive(dot(mat.N, Li.L));

	float oren = light_PBR_oren_diffuse(-mat.nvpos, Li.L, mat.N, mat.roughness, NdotL, NdotV);
	float att = max(0.0, Li.light.attenuation * (thin_sublayer_mask ? 1.0 : oren));
	if (!thin_sublayer_mask) {
		att += 0.9 * (1.0 - att) * max(0.0, pow3(1.0 - subSurfaceThick) * (0.5 + 0.5 * dot(Li.L, mat.nvpos)));
	}
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

vec3 light_calc_PBR_IBL(in vec3 color, in vec3 L, Material mat, in vec3 env) {
	vec3 H = normalize(L - mat.nvpos);
	vec3 F0 = vec3(0.02);
	F0 = mix(F0, mat.albedo, mat.metalic * 0.5);

	vec3 F = light_PBR_fresnelSchlickRoughness(Positive(dot(H, -mat.nvpos)), F0, mat.roughness);

	return mix(color, env, (1.0 - mat.roughness) * F);
}

vec4 light_calc_PBR_IBL(in vec4 color, in vec3 L, Material mat, in vec3 env) {
	vec3 H = normalize(L - mat.nvpos);
	vec3 F0 = vec3(0.02);
	F0 = mix(F0, mat.albedo, mat.metalic * 0.5);

	vec3 F = light_PBR_fresnelSchlickRoughness(Positive(dot(H, -mat.nvpos)), F0, mat.roughness);
	vec3 factor = (1.0 - mat.roughness) * F;

	return vec4(mix(color.rgb, env, factor), color.a + (1.0 - color.a) * luma(factor));
}

//==============================================================================
// Ray Trace (Screen Space Reflection)
//==============================================================================

#ifdef SSR
#define SSR_STEPS 20 // [16 20 32]

vec4 ray_trace_ssr (vec3 direction, vec3 start, float metal, sampler2D colorbuf, vec3 N) {
	vec3 testPoint = start;
	bool hit = false;
	float bayer = bayer_64x64(uv, vec2(viewWidth, viewHeight));
	vec2 uv = vec2(0.0);
	vec4 hitColor = vec4(0.0);

	float h = log(length(start)) * 0.45 + 0.1;
	bool bi = false;

	float sampleDepth = 0.1;
	float testDepth = far;

	for(int i = 0; i < SSR_STEPS; i++) {
		testPoint += direction * h;
		vec3 testPointJittered = testPoint + float(!bi) * direction * h * (bayer * 0.2 - 0.1);
		bayer = fract(bayer + 0.618);

		uv = screen_project(testPointJittered);
		if(clamp(uv, vec2(0.0), vec2(1.0)) != uv) {
			hit = true;
			break;
		}

		#ifdef HIGH_LEVEL_SHADER
		sampleDepth = linearizeDepth(texelFetch2D(depthtex1, ivec2(uv * vec2(viewWidth, viewHeight)), 0).x);
		#else
		sampleDepth = linearizeDepth(texture2D(depthtex1, uv).x);
		#endif
		testDepth = getLinearDepthOfViewCoord(testPointJittered);

		if (!bi) {
			bi = sampleDepth < testDepth + 0.005;
			testPoint = testPointJittered;
		}

		if (bi) {
			h = far * (sampleDepth - testDepth) * 0.5;
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
#endif

#ifdef SSS
float screen_space_shadow (vec3 direction, vec3 start, vec3 N, float cdepth) {
	if (dot(N, direction) < 0.2 || length(start) > 16.0) return 0.0; 

	vec3 testPoint = start;
	float hit_am = 0.0;
	bool hit = false;

	float h = 0.009 + max(cdepth - 4.0, 0.0) / far;
	bool bi = false;

	float sampleDepth, testDepth;

	vec2 uv;

	for(int i = 0; i < 16; i++) {
		testPoint += direction * h;
		uv = screen_project(testPoint);
		if(clamp(uv, vec2(0.0), vec2(1.0)) != uv) {
			break;
		}

		sampleDepth = linearizeDepth(texture2D(depthtex1, uv).x);
		testDepth = getLinearDepthOfViewCoord(testPoint);

		//if (!hit) hit = sampleDepth < testDepth;
		//
		//if (hit)
		//	h *= sampleDepth > testDepth ? 0.5 : -0.5;
		//} else {
		//	h *= 1.1;
		//}

		//if(hit && abs(testDepth - sampleDepth) < 0.001){
		if (sampleDepth < testDepth && abs(testDepth - sampleDepth) < 0.00016) {
			hit_am = 1.0;
			break;
		}
	}

	return hit_am;
}
#endif

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
const float rsam = 2.0 / float(Sample_Directions);

float calcAO (vec3 cNormal, float cdepth, vec3 vpos, vec2 uv) {
	float radius = 1.0 / cdepth;
	float ao = 0.0;

	float rand = bayer_64x64(uv, vec2(viewWidth, viewHeight));
	for (int i = 0; i < Sample_Directions; i++) {
		rand = fract(rand + 0.618);
		float dx = radius * pow2(rand);
		vec2 dir = ao_offset_table[i] * (dx + pixel * 2.0);

		vec2 h = uv + dir;
		vec3 nvpos = fetch_vpos(h, depthtex1).xyz;
		vec3 diff_pos = nvpos - vpos;

		float d = length(diff_pos) + 0.00001;

		ao += max(0.0, dot(cNormal, diff_pos) / d - 0.15)
		   * max(0.0, - (d * 0.27 - 1.0));
	}

	return 1.0 - sqrt(clamp(ao * rsam, 0.0, 1.0));
}
#endif
