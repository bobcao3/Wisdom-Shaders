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
#pragma optimize(on)

const int shadowMapResolution = 1512; // [256 1024 1512 2048 4096]
const float shadowDistance = 128.0; // [0 64 90 128.0 160 256]
const float sunPathRotation = -39.0;
const float shadowIntervalSize = 5.0;
const float ambientOcclusionLevel = 0.5f; // [0.0f 0.5f 1.0f]

uniform sampler2D gdepth;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;
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

const float eyeBrightnessHalflife = 18.5f;
uniform ivec2 eyeBrightnessSmooth;

varying vec2 texcoord;
varying vec3 suncolor;

varying float extShadow;

varying vec3 skycolor;
varying vec3 fogcolor;
varying vec3 horizontColor;

varying vec3 worldLightPos;

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
 vec4 vpos = vec4(texture2D(gdepth, texcoord).xyz, 1.0);
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

//#define USE_LOW_QUALITY_BAYER

#define g(a) (-4*a.x*a.y+3*a.x+2*a.y)

#ifdef USE_LOW_QUALITY_BAYER
float bayer_8x8(vec2 pos) {
	ivec2 p = ivec2(texcoord * vec2(viewWidth, viewHeight));

	ivec2 m0 = ivec2(mod(floor(p * 0.5), 2.0));
	ivec2 m1 = ivec2(mod(p, 2.0));
	return float(g(m0)+g(m1)*4) / 15.0f;
}
#else
float bayer_8x8(vec2 pos) {
	ivec2 p = ivec2(pos * vec2(viewWidth, viewHeight));

	ivec2 m0 = ivec2(mod(floor(p * 0.25), 2.0));
	ivec2 m1 = ivec2(mod(floor(p * 0.5), 2.0));
	ivec2 m2 = ivec2(mod(p, 2.0));
	return float(g(m0)+g(m1)*4+g(m2)*16) / 63.0f;
}
#endif

#undef g

#define AO_Enabled
#ifdef AO_Enabled

#define AO_HIGHQUALITY

#ifdef AO_HIGHQUALITY
const int Sample_Directions = 6;
const  vec2 offset_table[Sample_Directions + 1] = vec2 [] (
	vec2( 0.0,    1.0 ),
	vec2( 0.866,  0.5 ),
	vec2( 0.866, -0.5 ),
	vec2( 0.0,   -1.0 ),
	vec2(-0.866, -0.5 ),
	vec2(-0.866,  0.5 ),
	vec2( 0.0,    1.0 )
);
#else
const int Sample_Directions = 4;
const  vec2 offset_table[Sample_Directions + 1] = vec2 [] (
	vec2( 0.0,  1.0 ),
	vec2( 1.0,  0.0 ),
	vec2( 0.0, -1.0 ),
	vec2(-1.0,  0.0 ),
	vec2( 0.0,  1.0 )
);
#endif

float AO() {
	float am = 0.0;
	float d = 0.0042 / cdepthN;

	if (cdepthN < 0.85) {
		for (int i = 0; i < Sample_Directions; i++) {
			vec2 inc = normalize(offset_table[i] + offset_table[i + 1] * bayer_8x8(texcoord + i * 0.2));
			vec2 sample_cr = texcoord + inc * d * (0.1 + bayer_8x8(texcoord - i * 0.2));
			if (sample_cr.x > 1.0 || sample_cr.x < 0.0 || sample_cr.y > 1.0 || sample_cr.y < 0.0) continue;

			vec3 svpos = texture2D(gdepth, sample_cr).xyz;
			float occu = max(0.0, dot(svpos - vpos.xyz, normal) / distance(svpos, vpos.xyz) - 0.1);
			occu *= float(distance(svpos, vpos.xyz) < 1.5);

			am += occu / Sample_Directions;
		}
	}

	am = pow(am, 0.5);

	return clamp(1.0 - am, 0.0, 1.0);
}
#undef Sample_Directions
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

//#define GlobalIllumination
#ifdef GlobalIllumination

uniform sampler2D shadowcolor0;

const vec2 gi_offset[7] = vec2 [] (
	vec2( 0.0,    1.0 ),
	vec2( 0.866,  0.5 ),
	vec2( 0.866, -0.5 ),
	vec2( 0.0,   -1.0 ),
	vec2(-0.866, -0.5 ),
	vec2(-0.866,  0.5 ),
	vec2( 0.0,    1.0 )
);

vec3 GI() {
	vec3 gi = vec3(.0);

	vec3 trace_dir = -reflect(worldLightPos, vec3(0.0, 1.0, 0.0));

	if (flag > 0.11 && cdepthN < 0.6) {
		for (int i = 0; i < 6; i++) {
			// Sample 1
			vec2 inc = normalize(gi_offset[i] + bayer_8x8(texcoord + i * 0.1) * gi_offset[i + 1]);

			float dista = 2.0 * (0.1 + bayer_8x8(texcoord - i * 0.1));
			float distb = 4.0 * (bayer_8x8(texcoord));

			vec3 spos = wpos + vec3(inc.x, 0.0, inc.y) * dista * distb;
			spos += distb * trace_dir;
			spos = wpos2shadowpos(spos);

			float sample_depth = texture2D(shadowtex0, spos.xy).x;
			float sam2 = texture2D(shadowtex1, spos.xy).x;

			gi += float(abs(sample_depth - sam2) < 0.001 && sample_depth > spos.z && abs(sample_depth - spos.z) < 0.04) * texture2DLod(shadowcolor0, spos.xy, 1.0).xyz;

			// Sample 2
			distb = 4.0 + 4.0 * bayer_8x8(texcoord);

			spos = wpos + vec3(inc.x, 0.0, inc.y) * dista * distb;
			spos += distb * trace_dir;
			spos = wpos2shadowpos(spos);

			sample_depth = texture2D(shadowtex0, spos.xy).x;
			sam2 = texture2D(shadowtex1, spos.xy).x;

			gi += float(abs(sample_depth - sam2) < 0.001 && sample_depth > spos.z && abs(sample_depth - spos.z) < 0.04) * texture2DLod(shadowcolor0, spos.xy, 1.0).xyz;
		}
	}
	return gi * 0.01;
}

#endif

#define CrespecularRays
#define HIGH_QUALITY_Crespecular
#ifdef CrespecularRays

#ifdef HIGH_QUALITY_Crespecular
const float step = 48.0;
const float loop = 47;
#else
const float step = 8.0;
const float loop = 7;
#endif

float VL() {
	vec2 texc = texcoord * 2.0;
	if (texc.x > 1.0 || texc.y > 1.0) return 0.0;

	vec3 normaltex = texture2D(gnormal, texc).rgb;
	vec3 normal = mat3(gbufferModelViewInverse) * normalDecode(normaltex.xy);
	float total = 0.0;
	bool skydiscard = (normaltex.b > 0.01);

	if (skydiscard) {
		vec3 owpos = (gbufferModelViewInverse * vec4(texture2D(gdepth, texc).xyz, 1.0)).xyz;
		vec3 swpos = owpos;
		vec3 dir = owpos / step;
		float prev = 0.0;

		for (int i = 0; i < loop; i++) {
			swpos -= dir;
			float dither = bayer_8x8(texcoord + vec2(i) * 0.01);
			vec3 shadowpos = wpos2shadowpos(swpos + dir * dither);
			if (shadowpos.z + 0.0006 < texture2D(shadowtex0, shadowpos.xy).x) {
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
	vec3 normaltex = texture2D(gnormal, texcoord).rgb;
	vec3 water_normal_tex = texture2D(composite, texcoord).rgb;
	normal = normalDecode(normaltex.xy);
	wnormal = mat3(gbufferModelViewInverse) * normal;
	flag = (normaltex.b < 0.11 && normaltex.b > 0.01) ? normaltex.b : max(normaltex.b, water_normal_tex.b);
	if (normaltex.b < 0.09 && water_normal_tex.b > 0.9) flag = 0.99;
	bool issky = (flag < 0.01);

	float ao = 1.0;
	if (!issky) {
		#ifdef AO_Enabled
		if (flag > 0.22 && (flag < 0.71f || flag > 0.79f))
			ao = AO();
		#endif
	}

	#ifdef GlobalIllumination
	vec3 gir = GI();
	#endif

	float vl = 0.0;
	#ifdef CrespecularRays
	vl = VL();
	#endif

	vec4 specular_data = flag > 0.89f ? texture2D(gaux4, texcoord) : texture2D(gaux1, texcoord);

/* DRAWBUFFERS:2347 */
	gl_FragData[0] = vec4(normaltex.xy, water_normal_tex.xy);
	gl_FragData[1] = vec4(flag, ao, vl, 0.0);
	gl_FragData[2] = specular_data;
	#ifdef GlobalIllumination
	gl_FragData[3] = vec4(gir, 1.0);
	#endif
}
