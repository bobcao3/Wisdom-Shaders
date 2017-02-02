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
#extension GL_ARB_shading_language_420pack : require

#pragma optimize(on)

const int shadowMapResolution = 1512; // [1024 1512 2048 4096]
const float shadowDistance = 128.0; // [64 90 128.0 160 256]
const float sunPathRotation = -39.0;
const float shadowIntervalSize = 5.0;

uniform sampler2D gdepth;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex1;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float frameTimeCounter;

const float eyeBrightnessHalflife	 = 8.5f;
uniform ivec2 eyeBrightnessSmooth;

invariant in vec2 texcoord;
invariant flat in vec3 suncolor;

invariant flat in float TimeSunrise;
invariant flat in float TimeNoon;
invariant flat in float TimeSunset;
invariant flat in float TimeMidnight;
invariant flat in float extShadow;

invariant flat in vec3 skycolor;
invariant flat in vec3 fogcolor;
invariant flat in vec3 horizontColor;

invariant flat in vec3 worldLightPos;

const float PI = 3.14159;
const float hPI = PI / 2;

vec3 normalDecode(vec2 enc) {
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));
}

float flag;
 vec4 vpos = vec4(texture(gdepth, texcoord).xyz, 1.0);
 vec3 wpos = (gbufferModelViewInverse * vpos).xyz;
 vec3 normal;
 vec3 wnormal;
float cdepth = length(wpos);
float dFar = 1.0 / far;
float cdepthN = cdepth * dFar;

#define luma(color) dot(color,vec3(0.2126, 0.7152, 0.0722))

float hash( vec2 p ) {
	float h = dot(p,vec2(127.1,311.7));
	return fract(sin(h)*43758.5453123);
}

float rand( in vec2 p ) {
	vec2 i = floor( p );
	vec2 f = fract( p );
	vec2 u = f*f*(3.0-2.0*f);
	return -1.0+2.0*mix( mix( hash( i + vec2(0.0,0.0) ),
	hash( i + vec2(1.0,0.0) ), u.x),
	mix( hash( i + vec2(0.0,1.0) ),
	hash( i + vec2(1.0,1.0) ), u.x), u.y);
}

float find_closest(vec2 pos) {
	const int ditherPattern[64] = int[64](
		0, 32, 8, 40, 2, 34, 10, 42, /* 8x8 Bayer ordered dithering */
		48, 16, 56, 24, 50, 18, 58, 26, /* pattern. Each input pixel */
		12, 44, 4, 36, 14, 46, 6, 38, /* is scaled to the 0..63 range */
		60, 28, 52, 20, 62, 30, 54, 22, /* before looking in this table */
		3, 35, 11, 43, 1, 33, 9, 41, /* to determine the action. */
		51, 19, 59, 27, 49, 17, 57, 25,
		15, 47, 7, 39, 13, 45, 5, 37,
		63, 31, 55, 23, 61, 29, 53, 21);

	vec2 positon = vec2(0.0f);
	positon.x = floor(mod(texcoord.s * viewWidth, 8.0f));
	positon.y = floor(mod(texcoord.t * viewHeight, 8.0f));

	int dither = ditherPattern[int(positon.x) + int(positon.y) * 8];

	return float(dither) / 64.0f;
}

#define AO_Enabled
#ifdef AO_Enabled

#define Sample_Directions 6
const  vec2 offset_table[Sample_Directions + 1] = vec2 [] (
	vec2( 0.0,    1.0 ),
	vec2( 0.866,  0.5 ),
	vec2( 0.866, -0.5 ),
	vec2( 0.0,   -1.0 ),
	vec2(-0.866, -0.5 ),
	vec2(-0.866,  0.5 ),
	vec2( 0.0,    1.0 )
);
#define sampleDepth 3

float AO() {
	float am = 0;
	// float rcdepth = texture(depthtex0, texcoord).r * 200.0f;
	float d = 0.0022 / cdepthN;
	float maxAngle = 0.0;
	if (cdepthN < 0.7) {
		for (int i = 0; i < Sample_Directions; i++) {
			for (int j = 1; j < sampleDepth; j++) {
				float noise = find_closest(texcoord + vec2(i, j) * 0.001);
				float inc = (j - 1 + noise) * d;
				float noise_angle = find_closest(texcoord - vec2(i, j) * 0.001);
				vec2 dir = mix(offset_table[i], offset_table[i + 1], noise_angle) * inc + texcoord;
				if (dir.x > 0.0 && dir.x < 1.0 && dir.y > 0.0 && dir.y < 1.0) {
					vec3 nVpos = texture(gdepth, dir).xyz;
					if (texture(gnormal, dir).b > 0.11) {
						float NdC = distance(nVpos, vpos.xyz);
						if (NdC < 1.25) {
							float angle = clamp(0.0, dot(nVpos - vpos.xyz, normal) / NdC - 0.2, 0.7);
							if (angle > maxAngle) {
								maxAngle = angle;
								float datt = sampleDepth * d;
								am += angle * (datt - inc) / datt / j * 0.5;
							}
						}
					}
				}
			}
		}
	}
	return clamp(0.0, 1.0 - am, 1.0);
}
#endif

#define SHADOW_MAP_BIAS 0.9
uniform sampler2D shadowtex0;
vec3 wpos2shadowpos(in  vec3 wpos) {
	 vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
	shadowposition.xy /= distortFactor;
	shadowposition /= shadowposition.w;
	shadowposition = shadowposition * 0.5f + 0.5f;
	return shadowposition.xyz;
}

#define GlobalIllumination
#ifdef GlobalIllumination

uniform sampler2D shadowcolor0;


/*
vec3 shadowpos2wpos(in vec3 spos) {
	vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
	shadowposition.xy /= distortFactor;
	shadowposition /= shadowposition.w;
	shadowposition = shadowposition * 0.5f + 0.5f;
	return shadowposition.xyz;
}*/

vec3 GI() {
	vec2 texc = texcoord * 2.0;
	if (texc.x > 1.0 || texc.y > 1.0) return vec3(0.0);

	vec3 ntex = texture(gnormal, texc).rgb;
	vec3 normal = mat3(gbufferModelViewInverse) * normalDecode(ntex.xy);

	vec3 accumulated = vec3(.0);

	if (ntex.b > 0.11) {

		vec3 owpos = (gbufferModelViewInverse * vec4(texture(gdepth, texc).xyz, 1.0)).xyz;
		vec3 flat_normal = normalize(cross(dFdx(owpos),dFdy(owpos)));
		// Direction 1
		vec3 swpos = owpos + flat_normal * 0.2;
		vec3 trace_dir = -reflect(-worldLightPos, vec3(find_closest(texcoord + vec2(owpos.xy)) * 0.2, 1.0, find_closest(texcoord + vec2(owpos.zy)) * 0.2));
		trace_dir = normalize(trace_dir) * 0.2;
		float prev = 0;

		for (int i = 0; i < 15; i++) {
			swpos += trace_dir;
			float dither = find_closest(texcoord + vec2(i) * 0.01);
			vec3 shadowpos = wpos2shadowpos(swpos + trace_dir * dither);
			if (abs(shadowpos.z - texture(shadowtex0, shadowpos.xy).x) < 0.0004) {
				vec3 color = texture(shadowcolor0, shadowpos.xz).rgb;
				accumulated += (prev + 1.0) * length(trace_dir) * (1 + dither) * 0.005 * suncolor * color;
				prev = 1.0;
			}
		}
		// Direction 2
		swpos = owpos + flat_normal * 0.2;
		trace_dir = -reflect(-worldLightPos, vec3(find_closest(texcoord + vec2(owpos.yx)) * 0.2, 1.0, find_closest(texcoord + vec2(owpos.zx)) * 0.2));
		trace_dir = normalize(trace_dir) * 0.2;
		prev = 0;

		for (int i = 0; i < 15; i++) {
			swpos += trace_dir;
			float dither = find_closest(texcoord + vec2(i) * 0.01);
			vec3 shadowpos = wpos2shadowpos(swpos + trace_dir * dither);
			if (abs(shadowpos.z - texture(shadowtex0, shadowpos.xy).x) < 0.0004) {
				vec3 color = texture(shadowcolor0, shadowpos.xz).rgb;
				accumulated += (prev + 1.0) * length(trace_dir) * (1 + dither) * 0.005 * suncolor * color;
				prev = 1.0;
			}
		}
	}
	return accumulated;
}

#endif

#define CrespecularRays
#ifdef CrespecularRays
float VL() {
	vec2 texc = texcoord * 2.0;
	if (texc.x > 1.0 || texc.y > 1.0) return 0.0;

	vec3 normaltex = texture(gnormal, texc).rgb;
	vec3 normal = mat3(gbufferModelViewInverse) * normalDecode(normaltex.xy);
	float total = 0.0;
	bool skydiscard = (normaltex.b > 0.01);

	if (skydiscard) {
		vec3 owpos = (gbufferModelViewInverse * vec4(texture(gdepth, texc).xyz, 1.0)).xyz;
		vec3 swpos = owpos;
		vec3 dir = owpos / 48.0;
		float prev = 0.0;

		for (int i = 0; i < 47; i++) {
			swpos -= dir;
			float dither = find_closest(texcoord + vec2(i) * 0.01);
			vec3 shadowpos = wpos2shadowpos(swpos + dir * dither);
			if (shadowpos.z + 0.0006 < texture(shadowtex0, shadowpos.xy).x) {
				total += (prev + 1.0) * length(dir) * (1 + dither) * 0.5;
				prev = 1.0;
			}
		}
	}

	total = min(total, 512.0);

	return total / 512.0;
}
#endif

void main() {
	vec3 normaltex = texture(gnormal, texcoord).rgb;
	vec3 water_normal_tex = texture(composite, texcoord).rgb;
	normal = normalDecode(normaltex.xy);
	wnormal = mat3(gbufferModelViewInverse) * normal;
	flag = (normaltex.b < 0.11 && normaltex.b > 0.01) ? normaltex.b : max(normaltex.b, water_normal_tex.b);
	bool issky = (flag < 0.01);

	float ao = 1.0;
	if (!issky) {
		#ifdef AO_Enabled
		if (flag > 0.22 && (flag < 0.71f || flag > 0.79f))
			ao = clamp(0.0, AO(), 1.0);
		#endif
	}

	#ifdef GlobalIllumination
	vec3 gir = GI();
	#endif

	float vl = 0.0;
	#ifdef CrespecularRays
	vl = VL();
	#endif

/* DRAWBUFFERS:237 */
	gl_FragData[0] = vec4(normaltex.xy, water_normal_tex.xy);
	gl_FragData[1] = vec4(flag, ao, vl, 0.0);
	#ifdef GlobalIllumination
	gl_FragData[2] = vec4(gir, 1.0);
	#endif
}
