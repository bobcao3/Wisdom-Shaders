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

#version 130
#extension GL_ARB_separate_shader_objects : require
#extension GL_ARB_shading_language_420pack : require
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

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform vec3 upVec;
uniform float wetness;
uniform float rainStrength;

uniform bool isEyeInWater;

layout(location = 0) invariant in vec2 texcoord;
layout(location = 1) invariant flat in vec3 suncolor;

layout(location = 2) invariant flat in float TimeSunrise;
layout(location = 3) invariant flat in float TimeNoon;
layout(location = 4) invariant flat in float TimeSunset;
layout(location = 5) invariant flat in float TimeMidnight;
layout(location = 6) invariant flat in float extShadow;

layout(location = 7) invariant flat in vec3 skycolor;
layout(location = 8) invariant flat in vec3 fogcolor;
layout(location = 9) invariant flat in vec3 horizontColor;

layout(location = 10) invariant flat in vec3 worldLightPos;

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
};

struct Material {
	vec4 vpos;
	lowp vec3 normal;
	vec3 wpos;
	lowp vec3 wnormal;
	float cdepth;
	float cdepthN;
};

struct Global {
	vec4 normaltex;
	vec4 mcdata;
} g;

Material frag;
Mask frag_mask;

vec3 color = texture(composite, texcoord).rgb;

void init_struct() {
	frag.vpos = vec4(texture(gdepth, texcoord).xyz, 1.0);
	frag.wpos = (gbufferModelViewInverse * frag.vpos).xyz;
	frag.normal = normalDecode(g.normaltex.xy);
	frag.wnormal = mat3(gbufferModelViewInverse) * frag.normal;
	frag.cdepth = length(frag.wpos);
	frag.cdepthN = frag.cdepth * dFar;
	frag_mask.flag = g.mcdata.a;
	frag_mask.is_valid = (frag_mask.flag > 0.01);
	frag_mask.is_water = (frag_mask.flag > 0.71f && frag_mask.flag < 0.79f);
	frag_mask.is_glass = (frag_mask.flag > 0.93);
	frag_mask.is_trans = frag_mask.is_water || frag_mask.is_glass;
}

#define SHADOW_MAP_BIAS 0.9
float fast_shadow_map(in vec3 wpos) {
	if (frag.cdepthN > 0.9f)
		return 0.0f;
	float shade = 0.0;
	vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
	shadowposition.xy /= distortFactor;
	shadowposition /= shadowposition.w;
	shadowposition = shadowposition * 0.5f + 0.5f;
	float shadowDepth = texture(shadowtex0, shadowposition.st).r;
	shade = float(shadowDepth + 0.0005f + frag.cdepthN * 0.05 < shadowposition.z);
	float edgeX = abs(shadowposition.x) - 0.9f;
	float edgeY = abs(shadowposition.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade -= clamp((frag.cdepthN - 0.7f) * 5.0f, 0.0f, 1.0f);
	shade = clamp(shade, 0.0f, 1.0f);
	return max(shade, extShadow);
}

const vec3 SEA_WATER_COLOR = vec3(0.6,0.83,0.96);

float hash( vec2 p ) {
	float h = dot(p,vec2(127.1,311.7));
	return fract(sin(h)*43758.5453123);
}

float noise( in vec2 p ) {
	vec2 i = floor( p );
	vec2 f = fract( p );
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0+2.0*mix( mix( hash( i + vec2(0.0,0.0) ),
	hash( i + vec2(1.0,0.0) ), u.x),
	mix( hash( i + vec2(0.0,1.0) ),
	hash( i + vec2(1.0,1.0) ), u.x), u.y);
}

// sea
const int ITER_GEOMETRY = 5;
const float SEA_HEIGHT = 0.43;
const float SEA_CHOPPY = 5.0;
const float SEA_SPEED = 0.8;
const float SEA_FREQ = 0.16;
float SEA_TIME = 1.0 + frameTimeCounter * SEA_SPEED;
mat2 octave_m = mat2(1.6,1.1,-1.2,1.6);


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

	float d, h = 0.0;
	for(int i = 0; i < ITER_GEOMETRY; i++) {
		d = sea_octave((uv+SEA_TIME)*freq,choppy);
		d += sea_octave((uv-SEA_TIME)*freq,choppy);
		h += d * amp;
		uv *= octave_m; freq *= 1.9; amp *= 0.18;
		choppy = mix(choppy,1.0,0.2);
	}
	float depth_bias = clamp(0.22, distance(frag.wpos + cameraPosition, p) * 0.02, 1.0);
	depth_bias = mix(depth_bias, 1.0, min(1.0, length(p - cameraPosition) * 0.01));
	return (h - SEA_HEIGHT) * depth_bias;
}

#define luma(color) dot(color,vec3(0.2126, 0.7152, 0.0722))

vec3 get_water_normal(in vec3 wwpos, in vec3 displacement) {
	float lod = max(length(wwpos - cameraPosition) / 256.0, 0.01);
	vec3 w1 = vec3(lod, getwave(wwpos + vec3(lod, 0.0, 0.0)), 0.0);
	vec3 w2 = vec3(0.0, getwave(wwpos + vec3(0.0, 0.0, lod)), lod);
	#define w0 displacement
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

#define PBR

#ifdef PBR

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

#endif

vec4 calcCloud(in vec3 wpos, inout vec3 sunLuma) {
	if (wpos.y < 0.03) return vec4(0.0);

	vec3 spos = wpos / wpos.y * 2850.0;
	float total;
	vec2 ns = spos.xz + cameraPosition.xz + frameTimeCounter * vec2(18.0, 2.0);
	ns.y *= 0.73;
	ns *= 0.0008;

	// Shape
	float f, l;
	l  = 0.50000 * noise(ns); ns = ns * 2.02;
	f  = mix(l, abs(l), rainStrength);
	l  = 0.25000 * noise(ns); ns = ns * 2.03;
	f += mix(l, abs(l), rainStrength);
	f += 0.12500 * noise(ns);
	f += 0.07300 * noise(ns * 2.0);
	f += abs(0.03100 * noise(ns * 4.0));
	f += abs(0.03100 * noise(ns * 14.0));
	f += 0.03100 * noise(ns * 8.0);
	f += abs(0.01100 * noise(ns * 10.0) * f);

	total = f;

	ns *= 0.1;
	l  = 0.50000 * noise(ns); ns = ns * 1.62;
	f  = mix(l, abs(l), rainStrength);
	l  = 0.25000 * noise(ns); ns = ns * 1.63;
	f += mix(l, abs(l), rainStrength);
	f += 0.12500 * noise(ns);

	total = total * 0.4 + f * total * 0.5 + f * 0.1;

	ns *= 2.0;
	ns += frameTimeCounter * 0.06;
	f  = 0.50000 * noise(ns); ns = ns * 0.7;
	f += 0.25000 * noise(ns); ns = ns * 0.9;
	f += 0.12500 * noise(ns);
	total += f * total;

	float weight = 0.4;
	f = 0.0; ns *= 3.0;
	for (int i=0; i<5; i++){
		f += abs(weight * noise(ns + frameTimeCounter * 0.03));
		ns = 1.2 * ns;
		weight *= 0.6;
	}
	total += f * total;

	total = clamp(0.0, total, 1.0);

	vec3 cloud_color = skycolor + horizontColor;
	cloud_color *= 1.0 - rainStrength * 0.8;
	cloud_color += pow(max(0.0, dot(wpos, worldLightPos)), 9.0) * horizontColor * (1.0 - total);
	total *= 1.0 - min(1.0, (length(wpos.xz) - 0.9) * 10.0);

	total = clamp(0.0, total, 1.0);
	sunLuma += pow(max(0.0, dot(wpos, worldLightPos)), 3.0) * suncolor * total;

	return vec4(cloud_color, total);
}

vec3 calcSkyColor(in vec3 wpos, float shade) {
	float horizont = abs(wpos.y + cameraPosition.y - 0.5);
	float skycolor_position = clamp(max(pow(max(1.0 - horizont / (35.0 * 100.0),0.01),8.0)-0.1,0.0), 0.35, 1.0);
	float horizont_position = max(pow(max(1.0 - horizont / (16.5*100.0) ,0.01),3.0)-0.1,0.0);

	vec3 sky = skycolor * skycolor_position * vec3(1.5 , 2.3, 2.6);
	sky = mix(sky, horizontColor * 0.6, horizont_position);

	float sun_glow = max(0.0, dot(worldLightPos, normalize(wpos)));
	sky += pow(sun_glow, 4.0) * 0.23 * suncolor * (1.0 - extShadow) * (1.0 - shade) * (1.0 + TimeMidnight * 10.0);

	// Sun.
	sky += clamp(pow(sun_glow, 690.0), 0.0, 0.2) * suncolor.rgb * (1.0 - rainStrength * 0.6) * 10.0 * (1.0 - shade) * (1.0 - extShadow) * (1.0 + TimeMidnight * 17.0);

	vec4 cloud = calcCloud(normalize(wpos), sky);
	sky = mix(sky, cloud.rgb, cloud.a);

	return sky;
}

#define rand(co) fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453)
#define PLANE_REFLECTION
#ifdef PLANE_REFLECTION

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; SEARCHPOINT+= DIRVEC * SIGN; uv = getScreenCoordByViewCoord(SEARCHPOINT); sampleDepth = linearizeDepth(textureLod(depthtex0, uv, 0.0).x); testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); SIGN = sign(sampleDepth - testDepth);

float linearizeDepth(float depth) {
	return (2.0 * near) / (far + near - depth * (far - near));
}

vec2 getScreenCoordByViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	if(p.z < -1 || p.z > 1)
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
		float sampleDepth = textureLod(depthtex0, uv, 0.0).x;
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
			hitColor = vec4(textureLod(composite, uv, 3.0 - metal * 3.0).rgb, 0.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0);
			float newflag = texture(gaux2, uv).a;
			hitColor.a *= 1.0 - float(newflag > 0.71f && newflag < 0.79f);
			hit = true;
			break;
		}
		lastPoint = testPoint;
	}
	if(!hit) {
		vec2 uv = getScreenCoordByViewCoord(lastPoint);
		float testDepth = getLinearDepthOfViewCoord(lastPoint);
		float sampleDepth = texture(depthtex0, uv).x;
		if(sampleDepth < 0.9 && testDepth - linearizeDepth(sampleDepth) < 1.0) {
			hitColor = vec4(texture2DLod(composite, uv, 2.0).rgb, 1.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 2.0), 0.0, 1.0);
		}
	}
	return hitColor;
}
#endif


#define ENHANCED_WATER
#define WATER_PARALLAX
#ifdef WATER_PARALLAX
vec3 WaterParallax(vec3 wpos, vec3 viewDir) {
	// number of depth layers
	const float minLayers = 3;
	const float maxLayers = 12;

	float numLayers = mix(maxLayers, minLayers, abs(dot(vec3(0.0, 0.0, 1.0), viewDir)));
	float layerDepth = 1.0 / numLayers;
	float currentLayerDepth = 0.0;
	vec2 P = viewDir.xy / viewDir.z * 0.5;
	vec2 deltaTexCoords = P / numLayers;

	vec3  currentTexCoords     = wpos;
	float currentDepthMapValue = getwave(wpos + cameraPosition);

	for (int i = 0; i < numLayers; i++) {
		if (currentLayerDepth >= currentDepthMapValue) break;
		currentTexCoords -= vec3(deltaTexCoords.x, 0.0, deltaTexCoords.y);
		currentDepthMapValue = getwave(wpos + cameraPosition);
		currentLayerDepth += layerDepth;
	}

	vec3 prevTexCoords = currentTexCoords + vec3(deltaTexCoords.x, 0.0, deltaTexCoords.y);

	// get depth after and before collision for linear interpolation
	float afterDepth  = currentDepthMapValue - currentLayerDepth;
	float beforeDepth = getwave(wpos + cameraPosition) - currentLayerDepth + layerDepth;

	// interpolation of texture coordinates
	float weight = afterDepth / (afterDepth - beforeDepth);
	vec3 finalTexCoords = prevTexCoords * weight + currentTexCoords * (1.0 - weight);

	return finalTexCoords;
}
#endif
// #define BLACK_AND_WHITE

/* DRAWBUFFERS:3 */
void main() {
	g.normaltex = texture(gnormal, texcoord);
	g.mcdata = texture(gaux2, texcoord);
	init_struct();
	float shade = g.mcdata.b;

	float is_shaded = pow(g.mcdata.g, 10);
	float wetness2 = is_shaded * wetness;
	// * (max(dot(normal, vec3(0.0, 1.0, 0.0)), 0.0) * 0.5 + 0.5);
	vec3 ambientColor = vec3(0.155, 0.16, 0.165) * (luma(suncolor) * 0.3);

	/*
	float fragdepth = texture(depthtex0, texcoord).r;
	vec4 fragvec = gbufferProjectionInverse * vec4(texcoord, fragdepth, 1.0);
	fragvec /= fragvec.w;*/

	if (frag_mask.is_valid) {
		vec4 water_vpos = vec4(texture(gaux3, texcoord).xyz, 1.0);
		vec4 ovpos = water_vpos;
		vec3 water_wpos = (gbufferModelViewInverse * water_vpos).xyz;
		vec3 water_plain_normal;
		vec3 owpos = water_wpos;
		vec3 water_displacement;
		if (frag_mask.is_glass) {
			frag.vpos = water_vpos;
			frag.wpos = water_wpos;
			frag.normal = normalDecode(g.normaltex.zw);
		}
		if (isEyeInWater || frag_mask.is_water) {
			water_plain_normal = mat3(gbufferModelViewInverse) * normalDecode(g.normaltex.zw);

			#ifdef WATER_PARALLAX
			water_wpos = WaterParallax(water_wpos, water_vpos.xyz);
			float wave = getwave(water_wpos + cameraPosition);
			water_wpos -= wave * normalize(water_wpos);
			#else
			float wave = getwave(water_wpos + cameraPosition);
			vec2 p = water_vpos.xy / water_vpos.z * wave;
			wave = getwave(water_wpos + cameraPosition - vec3(p.x, 0.0, p.y));
			water_wpos -= wave * normalize(water_wpos);
			vec2 wp = length(p) * normalize(water_wpos).xz;
			water_wpos -= vec3(wp.x, 0.0, wp.y);
			#endif

			water_displacement = wave * water_plain_normal;
			vec3 water_normal = water_plain_normal;
			//water_wpos += water_displacement;
			if (water_plain_normal.y > 0.8) {
				water_normal = water_plain_normal + get_water_normal(water_wpos + cameraPosition, water_displacement);
				water_normal = normalize(water_normal);
			}

			vec3 vsnormal = normalize(mat3(gbufferModelView) * water_normal);
			water_vpos = gbufferModelView * vec4(water_wpos + water_displacement, 1.0);
			#ifdef ENHANCED_WATER
			const float refindex = 0.7;
			vec4 shifted_vpos = vec4(frag.vpos.xyz + normalize(refract(normalize(frag.vpos.xyz), vsnormal, refindex)), 1.0);
			shifted_vpos = gbufferProjection * shifted_vpos;
			shifted_vpos /= shifted_vpos.w;
			shifted_vpos = shifted_vpos * 0.5f + 0.5f;
			vec2 shifted = shifted_vpos.st;
			#else
			vec2 shifted = texcoord + water_normal.xz;
			#endif

			float shifted_flag = texture(gaux2, shifted).a;

			if (shifted_flag < 0.71f || shifted_flag > 0.92f) {
				shifted = texcoord;
			}
			frag.vpos = vec4(texture(gdepth, shifted).xyz, 1.0);
			float dist_diff = isEyeInWater ? min(length(water_vpos.xyz), length(frag.vpos.xyz)) : distance(frag.vpos.xyz, water_vpos.xyz);
			float dist_diff_N = pow(clamp(0.0, 1.0, dist_diff / 8.0), 0.35);
			float dist_diff_NL = pow(clamp(0.0, 1.0, dist_diff / 64.0), 0.55);

			vec3 org_color = color;
			color = texture(composite, shifted, 0.0).rgb;
			color = mix(color, texture(composite, shifted, 1.0).rgb, dist_diff_N * 0.8);
			color = mix(color, texture(composite, shifted, 2.0).rgb, dist_diff_N * 0.6);
			color = mix(color, texture(composite, shifted, 3.0).rgb, dist_diff_N * 0.4);

			color = mix(color, org_color, pow(length(shifted - vec2(0.5)) / 1.414f, 2.0));
			if (shifted.x > 1.0 || shifted.x < 0.0 || shifted.y > 1.0 || shifted.y < 0.0) {
				color *= 0.5 + pow(length(shifted - vec2(0.5)) / 1.414f, 2.0);
			}

			vec3 watercolor = skycolor * (0.15 - wetness * 0.05) * vec3(0.17, 0.41, 0.68) * luma(suncolor) * (1.0 - dist_diff_NL * 0.7);
			color = mix(color * SEA_WATER_COLOR, SEA_WATER_COLOR * skycolor * 0.3, dist_diff_N);

			shade = fast_shadow_map(water_wpos);

			frag.wpos = water_wpos;
			frag.normal = vsnormal;
			frag.vpos.xyz = water_vpos.xyz;
			frag.wnormal = water_normal;//normalize(0.2 * water_normal + water_plain_normal);
		}

		frag.wpos.y -= 1.67f;
		// Preprocess Specular
		vec4 org_specular = texture(gaux1, texcoord);
		#ifdef PBR
			vec3 specular = vec3(0.0);
			specular.r = min(org_specular.g, 0.9999);
			specular.g = org_specular.r;
			specular.b = org_specular.b;
		#else
			vec3 specular = org_specular.rgb;
			specular.g = specular.g * (1.0 - specular.r);
		#endif

		if (!frag_mask.is_water) {
			vec3 cwpos = frag.wpos + cameraPosition;
			float wetness_distribution = texture(noisetex, cwpos.xz * 0.01).r + texture(noisetex, cwpos.yz  * 0.01).r;
			wetness_distribution = wetness_distribution * 0.5 + 0.8 * (texture(noisetex, cwpos.zx * 0.002).r + texture(noisetex, cwpos.yx  * 0.002).r);
			wetness_distribution *= wetness_distribution * wetness2;
			wetness_distribution *= wetness_distribution;
			wetness_distribution = clamp(wetness_distribution, 0.0, 1.0);
			if (specular.g < 0.000001f) specular.g = 0.3;
			specular.g = clamp(0.003, specular.g - wetness2 * 0.005, 0.9999);
			specular.g = mix(specular.g, 0.1, wetness_distribution);

			specular.r = clamp(0.00001, specular.r + wetness2 * 0.25, 0.7);
			specular.r = mix(specular.r, 0.3, wetness_distribution);
		}

		if (!isEyeInWater){
			// Specular definition:
			//  specular.g -> Roughness
			//  specular.r -> Metalness (Reflectness)
			//  specular.b (PBR only) -> Light emmission (Self lighting)
			#ifdef PBR
			vec3 halfwayDir = normalize(lightPosition - normalize(frag.vpos.xyz));
			float stdNormal = DistributionGGX(frag.normal, halfwayDir, specular.g);
			float spec = max(dot(frag.normal, halfwayDir), 0.0) * stdNormal * specular.r;
			//spec = clamp(0.0, spec, 1.0 - wetness2 * 0.5);

			#define refvpos frag.vpos.xyz
			if (!isEyeInWater && specular.r > 0.01) {
				vec3 vs_plain_normal = mat3(gbufferModelView) * water_plain_normal;
				vec3 refvnormal = frag_mask.is_water ? mix(vs_plain_normal, frag.normal, 0.2) : frag.normal;
				vec3 viewRefRay = reflect(normalize(refvpos), normalize(refvnormal + vec3(rand(texcoord), 0.0, rand(texcoord.yx)) * specular.g * specular.g * 0.05));
				float reflection_fresnel_mul = frag_mask.is_trans ? 3.0 : 1.5;
				vec3 ref_albedo = mix(color, vec3(1.0), 1.0 - (1.0 - specular.r) * (1.0 - specular.g));
				float fresnel = 0.02 + 0.98 * pow(1.0 - dot(viewRefRay, refvnormal), reflection_fresnel_mul);
				#ifdef PLANE_REFLECTION
				vec4 reflection = waterRayTarcing(refvpos + refvnormal * max(0.4, length(refvpos.xyz) / far), viewRefRay, color, specular.r);
				vec3 ref_color = reflection.rgb * ref_albedo * (reflection.a * specular.r);
				#else
				vec4 reflection = vec4(0.0);
				vec3 ref_color = vec3(0.0);
				#endif

				vec3 wref = reflect(normalize(frag.wpos), frag.wnormal) * 480.0;
				ref_color += calcSkyColor(wref, shade) * (1.0 - reflection.a) * specular.r * ref_albedo;
				color = mix(color, ref_color, fresnel);
			}
			/*
			specular.g = clamp(0.0001, specular.g, 0.9999);
			vec3 V = normalize(vec3(wpos - vec3(0.0, 1.67, 0.0)));
			vec3 F0 = vec3(0.01);
			F0 = mix(F0, color, specular.g);
			vec3 F = fresnelSchlickRoughness(max(dot(normal, V), 0.0), F0, specular.r);

			vec3 no = GeometrySmith(normal, V, worldLightPos, specular.r) * stdNormal * F;
			float denominator = max(0.0, 4 * max(dot(V, normal), 0.0) * max(dot(worldLightPos, normal), 0.0) + 0.001);
			vec3 brdf = no / denominator;*/

			// Sun reflect // - F * specular.g
			vec3 sunref = (0.5 * (suncolor) * spec) * (1.0 - shade);
			if (frag_mask.is_trans) {
				float fresnel = 0.02 + 0.98 * pow(1.0 - dot(lightPosition, frag.normal), 3.0);
				sunref *= 0.5 * fresnel;
			}
			sunref *= (1.0 - extShadow) * (1.0 - wetness2 * 0.6);
			#else
			float shininess = 32.0f - 30.0f * specular.g;
			vec3 halfwayDir = normalize(lightPosition - normalize(vpos.xyz));
			// Sun reflect
			vec3 sunref = 0.5 * suncolor * spec * (1.0 - shade);
			#endif

			color += min(vec3(1.5), sunref);
			//color = reflection.rgb * reflection.a;

			frag.cdepth = length(max(frag.wpos, water_wpos));

			//color = mix(color, vec3(luma(color)), min(0.4, frag.cdepth * 0.025 * rainStrength));
			color = mix(color, skycolor, min(0.6, frag.cdepth * 0.02 * rainStrength));
		}
	} else {
		vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 1.0, 1.0f);
		viewPosition /= viewPosition.w;
		vec4 worldPosition = normalize(gbufferModelViewInverse * viewPosition) * 480.0 * 2.0;

		frag.wpos = worldPosition.xyz;

		color = calcSkyColor(frag.wpos, 0.0);
	}

	#ifdef BLACK_AND_WHITE
	color = vec3(luma(color));
	#endif

	gl_FragData[0] = vec4(clamp(vec3(0.0), color, vec3(6.0)), 1.0);
}
