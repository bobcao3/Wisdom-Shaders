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
precision mediump float;
#pragma optimize(on)

const int shadowMapResolution = 1512; // [1024 1512 2048 4096]
const float shadowDistance = 128.0; // [64 90 128.0 160 256]
const float sunPathRotation = -39.0;
const float shadowIntervalSize = 4.0;

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
invariant flat in vec3 worldLightPos;
invariant flat in vec3 suncolor;
invariant flat in float extShadow;

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
highp vec4 vpos = vec4(texture(gdepth, texcoord).xyz, 1.0);
highp vec3 wpos = (gbufferModelViewInverse * vpos).xyz;
lowp vec3 normal;
lowp vec3 wnormal;
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

#define AO_Enabled
#ifdef AO_Enabled

#define Sample_Directions 6
const lowp vec2 offset_table[Sample_Directions + 1] = vec2 [] (
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
	//lowp float rcdepth = texture(depthtex0, texcoord).r * 200.0f;
	lowp float d = 0.0012 / cdepthN;
	lowp float maxAngle = 0.0;
	if (cdepthN < 0.7) {
		for (int i = 0; i < Sample_Directions; i++) {
			for (int j = 1; j < sampleDepth; j++) {
				lowp float noise = clamp(0.001, abs(rand((texcoord + vec2(i, j)))), 1.0);
				lowp float inc = (0.4 + noise * 0.6) * j * d;
				lowp vec2 dir = mix(offset_table[i], offset_table[i + 1], noise * 0.4 + 0.6) * inc + texcoord;
				if (dir.x < 0.0 || dir.x > 1.0 || dir.y < 0.0 || dir.y > 1.0) continue;

				vec3 nVpos = texture(gdepth, dir).xyz;
				lowp float NdC = distance(nVpos, vpos.xyz);
				if (NdC >= 1.25) break;
				else {
					lowp float angle = clamp(0.0, dot(nVpos - vpos.xyz, normal) / NdC - 0.2, 0.7) * 0.5;
					if (angle > maxAngle) {
						maxAngle = angle;
						float datt = sampleDepth * d;
						am += angle * (datt - inc) / datt / j;
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
vec3 wpos2shadowpos(in highp vec3 wpos) {
	highp vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
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

const vec2 circle_offsets[25] = vec2[25](
	vec2(-0.48946f,-0.35868f),
	vec2(-0.17172f, 0.62722f),
	vec2(-0.47095f,-0.01774f),
	vec2(-0.99106f, 0.03832f),
	vec2(-0.21013f, 0.20347f),
	vec2(-0.78895f,-0.56715f),
	vec2(-0.10378f,-0.15832f),
	vec2(-0.57284f, 0.3417f ),
	vec2(-0.18633f, 0.5698f ),
	vec2( 0.35618f, 0.00714f),
	vec2( 0.28683f,-0.54632f),
	vec2(-0.4641f ,-0.88041f),
	vec2( 0.19694f, 0.6237f ),
	vec2( 0.69991f, 0.6357f ),
	vec2(-0.34625f, 0.89663f),
	vec2( 0.1726f , 0.28329f),
	vec2( 0.41492f, 0.8816f ),
	vec2( 0.1369f ,-0.97162f),
	vec2(-0.6272f , 0.67213f),
	vec2(-0.8974f , 0.42719f),
	vec2( 0.55519f, 0.32407f),
	vec2( 0.94871f, 0.26051f),
	vec2( 0.71401f,-0.3126f ),
	vec2( 0.04403f, 0.93637f),
	vec2( 0.62031f,-0.66735f)
);

vec3 GI() {
	vec2 texc = texcoord * 5.0;
	if (texc.x > 1.0 || texc.y > 1.0) return vec3(0.0);

	vec3 ntex = texture(gnormal, texc).rgb;
	vec3 normal = mat3(gbufferModelViewInverse) * normalDecode(ntex.xy);
	bool skydiscard = (ntex.b > 0.01);

	//if (skydiscard) {

		vec3 owpos = (gbufferModelViewInverse * vec4(texture(gdepth, texc).xyz, 1.0)).xyz;
		lowp vec3 flat_normal = normalize(cross(dFdx(owpos),dFdy(owpos)));
		vec3 nswpos = owpos + normal * 0.2;
		vec3 trace_dir = -reflect(-worldLightPos, vec3(rand(owpos.xy) * 0.01, 1.0, rand(owpos.zy) * 0.01)) * 0.2;
		float NdotL = dot(normal, trace_dir * 5.0);
		if (NdotL < 0.0) return vec3(0.0);

		// Half voxel trace, 2 steps 1 voxel
		for (int i = 0; i < 40; i++) {
			nswpos += trace_dir;
			vec3 swpos = nswpos + rand(vec2(i, owpos.z)) * trace_dir * 0.4;
			vec3 shadowpos = wpos2shadowpos(swpos);

			// Detect bounce
			float sample_depth = texture(shadowtex0, shadowpos.xy).x;
			//return vec3(sample_depth,sample_depth,sample_depth);
			float nd = shadowpos.z - sample_depth;
			if (abs(nd) < 0.0006) {
				vec3 bsearch_dir = trace_dir;

				bsearch_dir *= (nd > 0.0) ? -0.6 : 0.6;
				// Bisearch 1
				swpos += bsearch_dir;
				shadowpos = wpos2shadowpos(swpos);
				nd = shadowpos.z - texture(shadowtex0, shadowpos.xy).x;
				bsearch_dir *= (nd > 0.0) ? -0.6 : 0.6;
				// Bisearch 2
				swpos += bsearch_dir;
				shadowpos = wpos2shadowpos(swpos);
				nd = shadowpos.z - texture(shadowtex0, shadowpos.xy).x;
				bsearch_dir *= (nd > 0.0) ? -0.6 : 0.6;
				// Bisearch 3
				swpos += bsearch_dir;
				shadowpos = wpos2shadowpos(swpos);
				nd = shadowpos.z - texture(shadowtex0, shadowpos.xy).x;
				bsearch_dir *= (nd > 0.0) ? -0.6 : 0.6;
				// Bisearch 4
				swpos += bsearch_dir;
				shadowpos = wpos2shadowpos(swpos);
				nd = shadowpos.z - texture(shadowtex0, shadowpos.xy).x;
				bsearch_dir *= (nd > 0.0) ? -0.6 : 0.6;
				// Bisearch 5
				swpos += bsearch_dir;
				shadowpos = wpos2shadowpos(swpos);

				// Calculate normal & light contribution
				//vec3 snormal = normalize(cross(dFdx(shadowpos), dFdy(shadowpos)));
				lowp vec3 halfwayDir = normalize(trace_dir * 3.0 - normalize(owpos));

				lowp vec3 scolor = texture(shadowcolor0, shadowpos.xy).rgb;
				for (int i = 0; i < 25; i++) {
					for (int i = 0; i < 3; i++) {
						float randv = 0.0011 * (i + 1) * rand((shadowpos.xy + i * 0.03));
						vec2 shadow_uv = shadowpos.xy + circle_offsets[i] * randv;
						float cover = float(abs(texture(shadowtex0, shadowpos.xy).x - shadowpos.z) < 0.001 * (i + 1));
						scolor += cover * texture(shadowcolor0, shadow_uv).rgb;
					}
				}
				scolor /= 26.0f;
				scolor /= 4.0f;
				scolor *= dot(trace_dir * 5.0, flat_normal);

				return scolor.rgb * (6.5 - distance(swpos, owpos)) * 0.05 * (max(0.0, dot(normal, halfwayDir)) * 0.5 + 0.5) * suncolor;
			}
		}
	//}
	return vec3(0.0);
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
			float dither = rand((texcoord + vec2(i) * 0.1)) * 0.8;
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
