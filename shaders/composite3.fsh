/*
 * Copyright 2017 Cheng Cao
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// =============================================================================
//  PLEASE FOLLOW THE LICENSE AND PLEASE DO NOT REMOVE THE LICENSE HEADER
// =============================================================================
//  ANY USE OF THE SHADER ONLINE OR OFFLINE IS CONSIDERED AS INCLUDING THE CODE
//  IF YOU DOWNLOAD THE SHADER, IT MEANS YOU AGREE AND OBSERVE THIS LICENSE
// =============================================================================

#version 120
#extension GL_ARB_shader_texture_lod : require
#pragma optionNV (unroll all)
#pragma optimize(on)

const bool compositeMipmapEnabled = true;

uniform sampler2D depthtex0;
uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

uniform vec3 shadowLightPosition;
vec3 lightPosition = normalize(shadowLightPosition);
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform vec3 upVec;
uniform float wetness;
uniform float rainStrength;

uniform bool isEyeInWater;

varying vec2 texcoord;
varying vec3 suncolor;


varying float extShadow;

varying vec3 skycolor;
varying vec3 fogcolor;
varying vec3 horizontColor;

varying vec3 worldLightPos;
varying vec3 worldSunPosition;

vec3 normalDecode(in vec2 enc) {
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

const float PI = 3.14159;
const float hPI = PI / 2;

float dFar = 1.0 / far;

struct Mask {
	float flag;

	bool is_valid;
	bool is_water;
	bool is_trans;
	bool is_glass;
	bool is_plant;
};

struct Material {
	vec4 vpos;
	vec3 nvpos;

	vec3 normal;
	vec3 wpos;
	vec3 wnormal;
	float cdepth;
	float cdepthN;
};

struct Global {
	vec4 normaltex;
	vec4 mcdata;
} g;

Material frag;
Mask frag_mask;

vec3 color = texture2D(composite, texcoord).rgb;

void init_struct() {
	frag.vpos = vec4(texture2D(gdepth, texcoord).xyz, 1.0);
	frag.nvpos = normalize(frag.vpos.xyz);
	frag.wpos = (gbufferModelViewInverse * frag.vpos).xyz;
	frag.normal = normalDecode(g.normaltex.xy);
	frag.wnormal = mat3(gbufferModelViewInverse) * frag.normal;
	frag.cdepth = length(frag.wpos);
	frag.cdepthN = frag.cdepth * dFar;
	frag_mask.flag = g.mcdata.a;
	frag_mask.is_valid = isEyeInWater || (frag_mask.flag > 0.01 && frag_mask.flag < 0.97);
	frag_mask.is_water = (frag_mask.flag > 0.71f && frag_mask.flag < 0.79f);
	frag_mask.is_glass = (frag_mask.flag > 0.93);
	frag_mask.is_trans = frag_mask.is_water || frag_mask.is_glass;
	frag_mask.is_plant = (frag_mask.flag > 0.48 && frag_mask.flag < 0.53);
}

#define SHADOW_MAP_BIAS 0.9
float fast_shadow_map(in vec3 wpos) {
	if (frag.cdepthN > 0.9f)
		return 0.0f;
	#ifdef NOSHADOW
	return 1.0 - smoothstep(0.94, 1.0, g.mcdata.g);
	#else
	float shade = 0.0;
	vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
	shadowposition.xy /= distortFactor;
	shadowposition /= shadowposition.w;
	shadowposition = shadowposition * 0.5f + 0.5f;
	float shadowDepth = texture2D(shadowtex0, shadowposition.st).r;
	shade = float(shadowDepth + 0.0005f + frag.cdepthN * 0.05 < shadowposition.z);
	float edgeX = abs(shadowposition.x) - 0.9f;
	float edgeY = abs(shadowposition.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade -= clamp((frag.cdepthN - 0.7f) * 5.0f, 0.0f, 1.0f);
	shade = clamp(shade, 0.0f, 1.0f);
	return max(shade, extShadow);
	#endif
}

const vec3 SEA_WATER_COLOR = vec3(.55,.92,.99);

float hash(vec2 p) {
	vec3 p3  = fract(vec3(p.xyx) * 0.2031);
	p3 += dot(p3, p3.yzx + 19.19);
	return fract((p3.x + p3.y) * p3.z);
}

float noise( in vec2 p ) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0 + 2.0 * mix(
		mix(hash(i),                 hash(i + vec2(1.0,0.0)), u.x),
		mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0,1.0)), u.x),
	u.y);
}

// sea
#define SEA_HEIGHT 0.43 // [0.21 0.33 0.43 0.66]

const int ITER_GEOMETRY = 2;
const int ITER_GEOMETRY2 = 5;
const float SEA_CHOPPY = 3.0;
const float SEA_SPEED = 0.8;
const float SEA_FREQ = 0.16;
const mat2 octave_m = mat2(1.4,1.1,-1.2,1.4);

float sea_octave(vec2 uv, float choppy) {
	uv += noise(uv);
	vec2 wv = 1.0-abs(sin(uv));
	vec2 swv = abs(cos(uv));
	wv = mix(wv,swv,wv);
	return pow(1.0-pow(wv.x * wv.y,0.75),choppy);
}

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
		uv *= octave_m; freq *= 1.9; amp *= 0.22; wave_speed *= -1.3;
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
	for(int i = 0; i < ITER_GEOMETRY2; i++) {
		d = sea_octave((uv+wave_speed)*freq,choppy) * 2.0;
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= 0.22; wave_speed *= -1.3;
		choppy = mix(choppy,1.0,0.2);
	}

	float lod = pow(1.0 - length(p - cameraPosition) / 512.0, 0.5);

	return (h - SEA_HEIGHT) * lod;
}


#define luma(color) dot(color,vec3(0.2126, 0.7152, 0.0722))

vec3 get_water_normal(in vec3 wwpos, in vec3 displacement) {
	vec3 w1 = vec3(0.035, getwave2(wwpos + vec3(0.035, 0.0, 0.0)), 0.0);
	vec3 w2 = vec3(0.0, getwave2(wwpos + vec3(0.0, 0.0, 0.035)), 0.035);
	#define w0 displacement
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
	float a      = roughness*roughness;
	float a2     = a*a;
	float NdotH  = max(dot(N, H), 0.0);

	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom;

	return a2 / denom;
}

#define fresnelSchlickRoughness(cosTheta, F0, roughness) (F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0))

#define GeometrySchlickGGX(NdotV, k) (NdotV / (NdotV * (1.0 - k) + k))

float GeometrySmith(vec3 N, vec3 V, vec3 L, float k) {
	float NdotV = max(dot(N, V), 0.0);
	float NdotL = max(dot(N, L), 0.0);
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
}

#define CLOUDS

#ifdef CLOUDS
const mat2 rotate = mat2(1.86, -1.5, 1.5, 1.86);

float cloudNoise(in vec2 pos) {
	vec2 coord = pos + cameraPosition.xz + frameTimeCounter * vec2(9.0, 2.0);
	coord.y *= 0.73;
	coord *= 0.00032;

	// Shape
	vec2 dir = vec2(1.0, 0.1);
	float n = noise(coord) * 0.31;
	                            coord *= 3.0;  dir = rotate * dir; coord += dir * frameTimeCounter * 0.015;
	n += noise(coord) * 0.25;   coord *= 3.01; dir = rotate * dir; coord += dir * frameTimeCounter * 0.025;
	n += noise(coord) * 0.125;  coord *= 3.02; dir = rotate * dir; coord += dir * frameTimeCounter * 0.035;
	n += noise(coord) * 0.0625;	coord *= 3.03; dir = rotate * dir; coord += dir * frameTimeCounter * 0.045;
	n += pow(noise(coord), 2.0) * 0.0312;

	return smoothstep(0.0, 1.0, n + rainStrength * 0.3);
}

const float cloudMin = 2800.0;
const float cloudMax = 3912.0;
const float cloudThick = cloudMax - cloudMin;
const float cloudDense = (cloudMin + cloudMax) * 0.5;

//#define VOLUMETRIC_CLOUD
#ifdef VOLUMETRIC_CLOUD

#define g(a) (-4*a.x*a.y+3*a.x+2*a.y)
float bayer_8x8(vec2 pos) {
	ivec2 p = ivec2(pos * vec2(viewWidth, viewHeight));

	ivec2 m0 = ivec2(mod(floor(p * 0.25), 2.0));
	ivec2 m1 = ivec2(mod(floor(p * 0.5), 2.0));
	ivec2 m2 = ivec2(mod(p, 2.0));
	return float(g(m0)+g(m1)*4+g(m2)*16) / 63.0f;
}
#undef g

float cloud3D(vec3 wpos) {
	float h = cloudNoise(wpos.xz);
	return min(1.0, float(h > distance(wpos.y, cloudDense) * 2.0 / cloudThick) * h * 2.0);
}

vec4 calcCloud(in vec3 wpos, in vec3 mie) {
	if (wpos.y < 0.03) return vec4(0.0);

	vec3 spos = wpos / wpos.y * 2850.0;

	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		vec3 dither = wpos / wpos.y * 0.125 * bayer_8x8(texcoord + vec2(i / viewWidth)) * cloudThick;
		float s = cloud3D(spos + dither);
		spos += wpos / wpos.y * (cloudMax - cloudMin) * 0.125;
		total += s;
	}
	total *= 0.25;

	vec3 cloud_color = vec3(0.0);

	if (total > 0.0) {
		float coreh = cloudThick * (1.0 - total);
		vec3 r1 = vec3(20.0, 0.0, cloudThick * (1.0 - cloudNoise(spos.xz + vec2(20.0, 0.0))));
		r1.y -= coreh;
		vec3 r2 = vec3(0.0, 20.0, cloudThick * (1.0 - cloudNoise(spos.xz + vec2(0.0, 20.0))));

		vec3 n = normalize(cross(r1, r2));

		float density = dot(worldLightPos, n) * 0.5 + 0.5;
		float d2 = max(0.0, -dot(worldLightPos, n));

		cloud_color = (1.0 - density) * mie + (1.0 - d2) * 0.2 * fogcolor;
		total *= 1.0 - min(1.0, (length(wpos.xz) - 0.96) * 25.0);
		total = clamp(total, 0.0, 1.0);
	}

	return vec4(cloud_color, total);
}

#else

vec4 calcCloud(in vec3 wpos, in vec3 mie) {
	if (wpos.y < 0.03) return vec4(0.0);

	vec3 spos = wpos / wpos.y * cloudMin;
	float total = cloudNoise(spos.xz);

	vec3 cloud_color = vec3(0.0);

	if (total > 0.0) {
		float coreh = cloudThick * (1.0 - total);
		vec3 r1 = vec3(20.0, 0.0, cloudThick * (1.0 - cloudNoise(spos.xz + vec2(20.0, 0.0))));
		r1.y -= coreh;
		vec3 r2 = vec3(0.0, 20.0, cloudThick * (1.0 - cloudNoise(spos.xz + vec2(0.0, 20.0))));

		vec3 n = normalize(cross(r1, r2));

		float density = dot(worldLightPos, n) * 0.5 + 0.5;
		float d2 = max(0.0, -dot(worldLightPos, n));

		cloud_color = (1.0 - density) * mie + (1.0 - d2) * 0.2 * fogcolor;
		total *= 1.0 - min(1.0, (length(wpos.xz) - 0.96) * 25.0);

		total = clamp(total, 0.0, 1.0);
	}

	return vec4(cloud_color, total);
}

#endif
#endif

varying vec3 totalSkyLight;

vec3 calcSkyColor(vec3 wpos, float camHeight) {
	float h = sqrt(abs(wpos.y));

	vec3 sky = mix(vec3(0.8), totalSkyLight, h) * luma(horizontColor);

	sky += smoothstep(0.99, 0.992, 1.0 - distance(wpos, worldSunPosition) * 0.5) * suncolor;
	sky += smoothstep(0.96, 0.967, 1.0 - distance(wpos, -worldSunPosition) * 0.5) * 0.5 * (1.0 - rainStrength);

	#ifdef CLOUDS
	vec4 cloud = calcCloud(wpos, vec3(1.3) * luma(horizontColor));
	sky = mix(sky, cloud.rgb, cloud.a);
	#endif

	sky += pow(abs(dot(wpos, worldLightPos)), 10.0) * min(0.4, luma(horizontColor)) * suncolor;

	return sky;
}

#define rand(co) fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453)
#define PLANE_REFLECTION
#ifdef PLANE_REFLECTION

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; SEARCHPOINT+= DIRVEC * SIGN; uv = getScreenCoordByViewCoord(SEARCHPOINT); sampleDepth = linearizeDepth(texture2DLod(depthtex0, uv, 0.0).x); testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); SIGN = sign(sampleDepth - testDepth);

float linearizeDepth(float depth) { return (2.0 * near) / (far + near - depth * (far - near));}

vec2 getScreenCoordByViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	if(abs(p.z) > 1)
		return vec2(-1.0);
	p = p * 0.5f + 0.5f;
	return p.st;
}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(p.z * 0.5 + 0.5);
}

vec4 waterRayTarcing(vec3 startPoint, vec3 direction, vec3 color, float metal) {
	const float stepBase = 0.025;
	vec3 testPoint = startPoint;
	direction *= stepBase;
	bool hit = false;
	vec4 hitColor = vec4(0.0);
	vec3 lastPoint = testPoint;
	for(int i = 0; i < 40; i++) {
		testPoint += direction * pow(float(i + 1), 1.46);
		vec2 uv = getScreenCoordByViewCoord(testPoint + direction * rand(vec2((texcoord.x + texcoord.y) * 0.5, i * 0.01)));
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			hit = true;
			break;
		}
		float sampleDepth = texture2DLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);
		if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i))){
			vec3 finalPoint = lastPoint;
			float _sign = 1.0;
			direction = testPoint - lastPoint;
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			uv = getScreenCoordByViewCoord(finalPoint);
			hitColor = vec4(texture2DLod(composite, uv, 3.0 - metal * 3.0).rgb, 0.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0);
			float newflag = texture2D(gaux2, uv).a;
			hitColor.a *= 1.0 - float(newflag > 0.71f && newflag < 0.79f);
			hit = true;
			break;
		}
		lastPoint = testPoint;
	}
	return hitColor;
}
#endif

#define Brightness 4.0 // [1.0 2.0 4.0 6.0]

#define ENHANCED_WATER
#define WATER_PARALLAX
#ifdef WATER_PARALLAX
void WaterParallax(inout vec3 wpos, in float lod) {
	const int maxLayers = 4;

	vec3 nwpos = normalize(wpos);
	vec3 fpos = (nwpos / max(0.1, abs(nwpos.y))) * SEA_HEIGHT;
	float exph = 0.0;
	float hstep = 1.0 / float(maxLayers);

	float h;
	for (int i = 0; i < maxLayers; i++) {
		h = getwave(wpos + cameraPosition) * lod;
		hstep *= 1.3;

		if (h + 0.05 > exph) break;

		exph -= hstep;
		wpos += vec3(fpos.x, 0.0, fpos.z) * hstep;
	}
	wpos -= vec3(fpos.x, 0.0, fpos.z) * abs(h - exph) * hstep;
}
#endif
// #define BLACK_AND_WHITE
#define SKY_REFLECTIONS

//#define NOSHADOW

/* DRAWBUFFERS:3 */
void main() {
	g.normaltex = texture2D(gnormal, texcoord);
	g.mcdata = texture2D(gaux2, texcoord);
	init_struct();
	float shade = g.mcdata.b;

	float is_shaded = pow(g.mcdata.g, 10);
	float wetness2 = is_shaded * wetness;
	// * (max(dot(normal, vec3(0.0, 1.0, 0.0)), 0.0) * 0.5 + 0.5);
	vec3 ambientColor = vec3(0.155, 0.16, 0.165) * (luma(suncolor) * 0.3);

	vec4 org_specular = texture2D(gaux1, texcoord);
	if (frag_mask.is_glass || frag_mask.flag > 0.97) {
		vec4 shifted_vpos = vec4(frag.vpos.xyz + normalize(refract(frag.nvpos, normalDecode(g.normaltex.zw), 1.0f / 1.4f)), 1.0);
		shifted_vpos = gbufferProjection * shifted_vpos;
		shifted_vpos /= shifted_vpos.w;
		shifted_vpos = shifted_vpos * 0.5f + 0.5f;
		vec2 shifted = shifted_vpos.st;

		color = texture2D(composite, shifted).rgb;
		color += texture2DLod(composite, shifted, 1.0).rgb * 0.6;
		color += texture2DLod(composite, shifted, 2.0).rgb * 0.4;
		color *= 0.5;

		color = color * org_specular.rgb;//, org_specular.rgb, pow(org_specular.a, 3.0));

		if (frag_mask.is_valid) org_specular = vec4(0.1, 0.36, 0.0, 1.0);
	}

	// Preprocess Specular
	vec3 specular = vec3(min(org_specular.g, 0.9999), org_specular.rb);

	if (frag_mask.is_valid) {
		vec4 water_vpos = vec4(texture2D(gaux3, texcoord).xyz, 1.0);
		vec3 water_wpos = (gbufferModelViewInverse * water_vpos).xyz;
		vec3 water_plain_normal;
		if (frag_mask.is_glass) {
			frag.vpos = water_vpos;
			frag.wpos = water_wpos;
			frag.normal = normalDecode(g.normaltex.zw);
			frag.wnormal = mat3(gbufferModelViewInverse) * frag.normal;
			frag.cdepth = length(frag.vpos);
			frag.cdepthN = frag.cdepth / far;
		}

		if (isEyeInWater && frag.vpos.z > 0.99) {
			vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 1.0, 1.0f);
			viewPosition /= viewPosition.w;
			vec4 worldPosition = normalize(gbufferModelViewInverse * viewPosition) * 480.0 * 2.0;

			frag.wpos = worldPosition.xyz;
		}
		if (isEyeInWater || frag_mask.is_water) {
			#ifndef NOSHADOW
			vec3 vvnormal_plain = normalDecode(g.normaltex.zw);
			water_plain_normal = mat3(gbufferModelViewInverse) * vvnormal_plain;

			float lod = pow(dot(water_plain_normal, vec3(0.0, 1.0, 0.0)), 20.0);

			#ifdef WATER_PARALLAX
			if (!isEyeInWater && lod > 0.99) WaterParallax(water_wpos, lod);
			float wave = getwave2(water_wpos + cameraPosition) * lod;
			#else
			float wave = getwave2(water_wpos + cameraPosition) * lod;
			vec2 p = water_vpos.xy / water_vpos.z * wave;
			wave = getwave2(water_wpos + cameraPosition - vec3(p.x, 0.0, p.y));
			vec2 wp = length(p) * normalize(water_wpos).xz;
			water_wpos -= vec3(wp.x, 0.0, wp.y);
			#endif

			vec3 water_normal = mix(water_plain_normal, get_water_normal(water_wpos + cameraPosition, wave * water_plain_normal), lod);

			vec3 vsnormal = normalize(mat3(gbufferModelView) * water_normal);
			water_vpos = (!frag_mask.is_water && isEyeInWater) ? frag.vpos : gbufferModelView * vec4(water_wpos, 1.0);
			#ifdef ENHANCED_WATER
			const float refindex = 0.7;
			vec4 shifted_vpos = vec4(frag.vpos.xyz + normalize(refract(frag.nvpos, vsnormal, refindex)), 1.0);
			shifted_vpos = gbufferProjection * shifted_vpos;
			shifted_vpos /= shifted_vpos.w;
			shifted_vpos.st = shifted_vpos.st * 0.5f + 0.5f;
			vec2 shifted = shifted_vpos.st;
			#else
			vec2 shifted = texcoord + water_normal.xz * (0.2 * pow(1.0 - frag.cdepthN, 0.3));
			#endif

			float shifted_flag = texture2D(gaux2, shifted).a;

			if (shifted_flag < 0.71f || shifted_flag > 0.92f) shifted = texcoord;
			frag.vpos = vec4(texture2D(gdepth, shifted).xyz, 1.0);
			float dist_diff = isEyeInWater ? length(water_vpos.xyz) : distance(frag.vpos.xyz, water_vpos.xyz);
			float dist_diff_N = clamp(abs(dist_diff) / 12.0, 0.0, 1.0);

			vec3 org_color = color;
			color = texture2DLod(composite, shifted, 0.0).rgb;
			#ifdef ENHANCED_WATER
			color = mix(color, texture2DLod(composite, shifted, 1.0).rgb, dist_diff_N * 0.8);
			color = mix(color, texture2DLod(composite, shifted, 2.0).rgb, dist_diff_N * 0.6);
			color = mix(color, texture2DLod(composite, shifted, 3.0).rgb, dist_diff_N * 0.4);

			color = mix(color, org_color, pow(length(shifted - vec2(0.5)) / 1.414f, 2.0));

			frag.vpos = texture2D(gdepth, shifted);

			if (frag.vpos.z > water_vpos.z && frag.vpos.z > 0.99) color = calcSkyColor(normalize(frag.wpos), cameraPosition.y + frag.wpos.y);
			#endif

			vec3 watercolor = min(luma(horizontColor), 1.0) * color;
			float absorbtion = 2.0 / (dist_diff_N + 1.0) - 1.0;
			watercolor *= pow(vec3(absorbtion), vec3(1.0, 0.4, 0.5));
			vec3 waterfog = vec3(min(luma(horizontColor), 1.0)) * vec3(0.2f, 0.5f, 0.95f) * 0.15f;
			color = mix(waterfog, watercolor, smoothstep(0.0, 1.0, absorbtion));

			shade = fast_shadow_map(water_wpos);

			frag.wpos = water_wpos;
			frag.normal = vsnormal;
			frag.vpos.xyz = water_vpos.xyz;
			frag.nvpos = normalize(frag.vpos.xyz);
			frag.cdepth = length(water_vpos.xyz);
			frag.wnormal = water_normal;
			#else
			const vec3 wcolor = vec3(0.1569, 0.5882, 0.783);
			vec3 watercolor = wcolor * vec3(min(luma(horizontColor), 1.0));
			color = mix(color, watercolor, 0.1);

			frag.wpos = water_wpos;
			frag.vpos = gbufferModelView * vec4(water_wpos, 1.0);
			frag.nvpos = normalize(frag.vpos.xyz);
			vec3 vvnormal_plain = normalDecode(g.normaltex.zw);
			frag.normal = vvnormal_plain;
			frag.wnormal = mat3(gbufferModelViewInverse) * vvnormal_plain;
			frag.cdepth = length(water_vpos.xyz);
			#endif
		} else if (rainStrength > 0.0) {
			vec3 cwpos = frag.wpos + cameraPosition;
			float wetness_distribution = noise(cwpos.xz * 0.2) + noise(cwpos.yz * 0.2) * 0.7;
			wetness_distribution += 0.5 * (noise(cwpos.zx * 0.04) + 0.2 * noise(cwpos.yx * 0.04)) + 0.5;
			wetness_distribution = clamp(smoothstep(0.0, 1.0, wetness_distribution * wetness2), 0.0, 1.0);

			float bias = (frag_mask.is_plant) ? noise(cwpos.xz * 20.0 + cwpos.yz * 18.0) * 0.7 + 0.3 : 1.0;
			bias *= dot(frag.wnormal, vec3(0.0, 1.0, 0.0));

			if (specular.g < 0.000001f) specular.g = 0.4;
			specular.g = clamp(specular.g - wetness2 * 0.05 * bias, 0.003, 0.9999);
			specular.g = mix(specular.g, 0.01, wetness_distribution * bias);

			specular.r = clamp(specular.r + wetness2 * 0.15 * bias, 0.00001, 0.7);
			specular.r = mix(specular.r, 0.8, wetness_distribution * bias);
			//color = specular;
		}

		frag.wpos.y -= 1.62;

		if (!isEyeInWater){
			// Specular definition:
			//  specular.g -> Roughness
			//  specular.r -> Metalness (Reflectness)
			//  specular.b (PBR only) -> Light emmission (Self lighting)
			vec3 halfwayDir = normalize(lightPosition - frag.nvpos);
			//spec = clamp(0.0, spec, 1.0 - wetness2 * 0.5);

			vec3 ref_color = vec3(0.0);
			vec3 viewRefRay = vec3(0.0);
			if (!isEyeInWater && specular.r > 0.01) {
				vec3 vs_plain_normal = mat3(gbufferModelView) * water_plain_normal;
				viewRefRay = reflect(frag.nvpos, normalize(frag.normal + vec3(rand(texcoord), 0.0, rand(texcoord.yx)) * specular.g * specular.g * 0.05));
				#ifdef PLANE_REFLECTION
				vec3 refnormal = frag_mask.is_water ? normalize(mix(frag.normal, vs_plain_normal, 0.9)) : frag.normal;
				vec3 plainRefRay = reflect(frag.nvpos, normalize(refnormal + vec3(rand(texcoord), 0.0, rand(texcoord.yx)) * specular.g * specular.g * 0.05));

				vec4 reflection = waterRayTarcing(frag.vpos.xyz + refnormal * max(0.4, length(frag.vpos.xyz) / far), plainRefRay, color, specular.r);
				ref_color = reflection.rgb * reflection.a; // * specular.r;
				#else
				vec4 reflection = vec4(0.0);
				#endif

				float skyam = pow(frag_mask.is_trans ? org_specular.a : g.mcdata.g, 4.0);
				#ifdef SKY_REFLECTIONS
				vec3 wref = reflect(normalize(frag.wpos), frag.wnormal);
				if (frag_mask.is_water) wref.y = abs(wref.y);
				ref_color += calcSkyColor(wref, cameraPosition.y + frag.wpos.y) * (1.0 - reflection.a) * skyam;
				#else
				ref_color += skyColor * (1.0 - reflection.a) * specular.r * skyam;
				#endif
			}

			if (specular.r > 0.07) {
				vec3 F0 = frag_mask.is_water ? vec3(0.04) : vec3(specular.r * 0.77 + 0.02);
				F0 = mix(F0, color, 1.0 - specular.r);
				vec3 F = fresnelSchlickRoughness(max(dot(frag.normal, -frag.nvpos), 0.0), F0, specular.g);
				color += ref_color * F * (0.02 + 0.98 * pow(1.0 - dot(viewRefRay, frag.normal), 2.0));

				if (frag_mask.is_trans) {
					vec3 halfwayDir = normalize(lightPosition - frag.nvpos);
					float stdNormal = DistributionGGX(frag.normal, halfwayDir, specular.g);

					vec3 no = GeometrySmith(frag.normal, -frag.nvpos, lightPosition, specular.g) * stdNormal * F;
					float denominator = max(0.0, 4 * max(dot(-frag.nvpos, frag.normal), 0.0) * max(dot(lightPosition, frag.normal), 0.0) + 0.001);
					vec3 brdf = no / denominator;

					color += brdf * suncolor * ((1.0 - shade) * (1.0 - rainStrength));
				}
			}

			float fog_coord = clamp((512.0 - frag.cdepth) / (512.0 - 32.0), 0.0, 1.0);
			color = mix(fogcolor, color, fog_coord);
			frag.cdepth = length(max(frag.wpos, water_wpos));
		}
	} else {
		vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 1.0, 1.0f);
		viewPosition /= viewPosition.w;
		vec4 worldPosition = normalize(gbufferModelViewInverse * viewPosition);

		vec3 skycolor = calcSkyColor(worldPosition.xyz, cameraPosition.y);
		color = frag_mask.flag > 0.97 ? skycolor * org_specular.rgb : skycolor;
	}

	#ifdef BLACK_AND_WHITE
	color = vec3(luma(color));
	#endif

	gl_FragData[0] = vec4(max(color, vec3(0.0)), 1.0);
}
