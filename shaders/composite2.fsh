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
vec3 lightPosition = normalize(shadowLightPosition);
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float frameTimeCounter;

uniform bool isEyeInWater;

uniform ivec2 eyeBrightnessSmooth;

const float PI = 3.14159;
const float hPI = PI / 2;

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


#define saturate(x) clamp(0.0,x,1.0)

vec3 normalDecode(vec2 enc) {
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));
}

float linearizeDepth(float depth) {
	return (2.0 * near) / (far + near - depth * (far - near));
}

float flag;
//#define WHITE_WORLD
#ifdef WHITE_WORLD
vec3 color = vec3(0.75);
#else
vec3 color = texture(gcolor, texcoord).rgb;
#endif
vec4 vpos = vec4(texture(gdepth, texcoord).xyz, 1.0);
vec3 nvpos = normalize(vpos.xyz);
vec3 wpos = (gbufferModelViewInverse * vpos).xyz;
 vec3 wnormal;
 vec3 normal;
float cdepth = length(wpos);
float dFar = 1.0 / far;
float cdepthN = cdepth * dFar;
float NdotL;

const int shadowMapResolution = 1512; // [1024 1512 2048 4096]

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
const float circle_count = 25.0;

#define luma(color) dot(color,vec3(0.2126, 0.7152, 0.0722))

#define SHADOW_MAP_BIAS 0.9
float shadowTexSmooth(in sampler2D s, in vec2 texc, float spos) {
	vec2 pix_size = vec2(1.0) / (shadowMapResolution);

	float bias = cdepthN * 0.002;
	vec2 texc_m = texc * shadowMapResolution;

	vec2 px0 = vec2(texc + pix_size * vec2(0.5, 0.5));
	float texel = texture(s, px0, 0).x;
	float res1 = float(texel + bias < spos);

	vec2 px1 = vec2(texc + pix_size * vec2(0.5, -0.5));
	texel = texture(s, px1, 0).x;
	float res2 = float(texel + bias < spos);

	vec2 px2 = vec2(texc + pix_size * vec2(-0.5, -0.5));
	texel = texture(s, px2, 0).x;
	float res3 = float(texel + bias < spos);

	vec2 px3 = vec2(texc + pix_size * vec2(-0.5, 0.5));
	texel = texture(s, px3).x;
	float res4 = float(texel + bias < spos);

	float res = res1 + res2 + res3 + res4;

	return res * 0.25;
}

bool is_plant;

#define CAUSTIC
#ifdef CAUSTIC
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
#define ITER_GEOMETRY 5
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

#define OCTAVE d = sea_octave((uv+SEA_TIME)*freq,choppy); d += sea_octave((uv-SEA_TIME)*freq,choppy); h += d * amp; uv *= octave_m; freq *= 1.9; amp *= 0.18; choppy = mix(choppy,1.0,0.2);

float getwave(vec3 p) {
	float freq = SEA_FREQ;
	float amp = SEA_HEIGHT;
	float choppy = SEA_CHOPPY;
	vec2 uv = p.xz ; uv.x *= 0.75;

	float d, h = 0.0;

	OCTAVE
	OCTAVE
	OCTAVE
	OCTAVE
	OCTAVE

	float depth_bias = clamp(0.22, distance(wpos + cameraPosition, p) * 0.02, 1.0);
	depth_bias = mix(depth_bias, 1.0, min(1.0, length(p - cameraPosition) * 0.01));
	return h * depth_bias;
}

vec3 get_water_normal(in vec3 wwpos, in vec3 displacement) {
	vec3 w1 = vec3(0.1, getwave(wwpos + vec3(0.1, 0.0, 0.0)), 0.0);
	vec3 w2 = vec3(0.0, getwave(wwpos + vec3(0.0, 0.0, 0.1)), 0.1);
	vec3 w0 = displacement;
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}
#endif

#define rand(co) fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453)

const  vec2 offset_table[6] = vec2 [] (
	vec2( 0.0,    1.0 ),
	vec2( 0.866,  0.5 ),
	vec2( 0.866, -0.5 ),
	vec2( 0.0,   -1.0 ),
	vec2(-0.866, -0.5 ),
	vec2(-0.866,  0.5 )
);

#define SHADOW_FILTER
float shadow_map() {
	if (cdepthN > 0.9f)
		return is_plant ? 0.0 : 1.0 - (clamp(0.07f, NdotL, 1.0f) - 0.07f) * 1.07528f;
	float shade = 0.0;
	if (NdotL <= 0.05f && !is_plant) {
		shade = 1.0f;
	} else {
		vec4 shadowposition = shadowModelView * vec4(wpos + wnormal * 0.01, 1.0f);
		shadowposition = shadowProjection * shadowposition;
		float distb = length(shadowposition.xy);
		float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
		shadowposition.xy /= distortFactor;
		shadowposition /= shadowposition.w;
		shadowposition = shadowposition * 0.5f + 0.5f;

		#ifdef SHADOW_FILTER
			for (int i = 0; i < 25; i++) {
				float shadowDepth = texture(shadowtex1, shadowposition.st + circle_offsets[i] * 0.0008f).x;
				shade += float(shadowDepth + 0.00002 / distortFactor < shadowposition.z);
			}
			shade /= 25.0f;
		#else
			shade = shadowTexSmooth(shadowtex1, shadowposition.st, shadowposition.z);
		#endif

		float edgeX = abs(shadowposition.x) - 0.95f;
		float edgeY = abs(shadowposition.y) - 0.95f;
		shade -= max(0.0f, edgeX * 20.0f);
		shade -= max(0.0f, edgeY * 20.0f);
		shade = max(0.0, shade);
		if (!is_plant) {
			float phong = 1.0 - (clamp(0.07f, NdotL, 1.0f) - 0.07f) * 1.07528f;
			shade = max(shade, phong);
		}
	}
	return max(shade, extShadow);
}


uniform sampler2D gaux1;

#define GeometrySchlickGGX(NdotV, k) (NdotV / (NdotV * (1.0 - k) + k))

float GeometrySmith(vec3 N, vec3 V, vec3 L, float k) {
	float NdotV = max(dot(N, V), 0.0);
	float NdotL = max(dot(N, L), 0.0);
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
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

#define AO_Enabled
#ifdef AO_Enabled
float blurAO(float c, vec3 cNormal) {
	float a = c;
	 float d = 0.068 / cdepthN;

	for (int i = -5; i < 0; i++) {
		vec2 adj_coord = texcoord + vec2(0.0, 0.0027) * i * d;
		vec3 nvpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(composite, adj_coord).g, c, saturate(distance(nvpos, vpos.xyz))) * 0.2 * (6.0 - abs(float(i)));
	}

	for (int i = 1; i < 6; i++) {
		vec2 adj_coord = texcoord + vec2(0.0, 0.0027) * i * d;
		vec3 nvpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(composite, adj_coord).g, c, saturate(distance(nvpos, vpos.xyz))) * 0.2 * (6.0 - abs(float(i)));
	}

	return saturate(a * 0.1629 - 0.3) / 0.7;
}
#endif

#define GlobalIllumination
#ifdef GlobalIllumination
uniform sampler2D gaux4;
vec3 blurGI(vec3 c) {
	vec3 a = c;
	 float d = 0.068 / cdepthN;

	for (int i = -5; i < 0; i++) {
		vec2 adj_coord = texcoord + vec2(0.0, 0.0025) * i * d;
		vec3 nvpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(gaux4, adj_coord).rgb, c, saturate(distance(nvpos, vpos.xyz))) * 0.2 * (6.0 - abs(float(i)));
	}

	for (int i = 1; i < 6; i++) {
		vec2 adj_coord = texcoord + vec2(0.0, 0.0025) * i * d;
		vec3 nvpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(gaux4, adj_coord).rgb, c, saturate(distance(nvpos, vpos.xyz))) * 0.2 * (6.0 - abs(float(i)));
	}

	return a;
}
#endif

#define CrespecularRays

void main() {
	vec4 normaltex = texture(gnormal, texcoord);
	normal = normalize(normalDecode(normaltex.xy));
	wnormal = mat3(gbufferModelViewInverse) * normal;
	vec4 compositetex = texture(composite, texcoord);
	flag = compositetex.r;
	bool issky = (flag < 0.01);
	is_plant = (flag > 0.48 && flag < 0.53);
	vec2 mclight = vec2(0.0);
	float shade = 0.0;
	NdotL = dot(lightPosition, normal);
	// Preprocess Gamma 2.2
	color = pow(color, vec3(2.2f));
	vec3 fogColor;

	float eyebrightness = pow(float(eyeBrightnessSmooth.y) / 120.0, 2.0);
	vec3 ambientColor = vec3(0.135, 0.14, 0.215) * luma(horizontColor) * (1.0 - eyebrightness * 0.1) * 3.0;
	if (!issky) {
		shade = shadow_map();
		#ifdef CAUSTIC
		if (((flag > 0.71f && flag < 0.79f) && !isEyeInWater) || isEyeInWater) {
			float w = getwave(wpos.xyz + vec3(0.3, 0.0, 0.3) * (wpos.y + cameraPosition.y) + cameraPosition);
			shade += pow(clamp(0.0, w * 2.0, 1.0), 1.5) * 0.3;
			shade = clamp(shade, 0.0, 1.0);
		}
		#endif
		if(is_plant) shade /= 1.0 + mix(0.0, 1.0, pow(max(0.0, dot(nvpos, lightPosition)), 16.0));
		mclight = texture(gaux2, texcoord).xy;

		const vec3 torchColor = vec3(2.15, 1.01, 0.48) * 0.45;

		float light_distance = clamp(0.08, (1.0 - pow(mclight.x, 6.6)), 1.0);
		const float light_quadratic = 4.9f;
		float max_light = 7.5 * mclight.x * mclight.x;
		vec4 specular = texture(gaux1, texcoord);
		if (specular.b > 0.1 || pow(mclight.x, 6.0) > 0.9) {
			light_distance = 0.04;
			max_light = 13.5;
		}

		const float light_constant1 = 1.09f;
		const float light_constant2 = 1.09f;
		float attenuation = clamp(0.0, light_constant1 / (pow(light_distance, light_quadratic)) - light_constant2, max_light);

		vec3 diffuse_torch = attenuation * torchColor;
		vec3 diffuse_sun = (1.0 - shade) * suncolor * clamp(0.0, luma(skycolor) * 4.5, 1.0);

		bool is_plant = (flag > 0.49 && flag < 0.53);
		//if (flag < 0.6f || !is_plant) {
		//	diffuse_sun *= 0.63 + GeometrySmith(normal, normalize(wpos - vec3(0.0, -1.67, 0.0)), shadowLightPosition, specular.r) * 0.37;
		//}

		specular.r = clamp(0.01, specular.r, 0.99);
		vec3 V = nvpos;
		vec3 F0 = vec3(0.02);
		F0 = mix(F0, color, specular.g);
		vec3 F = fresnelSchlickRoughness(max(dot(normal, V), 0.0), F0, specular.r);

		vec3 halfwayDir = normalize(lightPosition - V);
		vec3 no = GeometrySmith(normal, V, lightPosition, specular.r) * DistributionGGX(normal, halfwayDir, specular.r) * F;
		float denominator = 4 * max(dot(V, normal), 0.0) * max(NdotL, 0.0) + 0.001;
		vec3 brdf = no / denominator;

		if(is_plant) shade /= 1.0 + mix(0.0, 2.0, max(0.0, pow(dot(halfwayDir, lightPosition), 16.0)));

		vec3 kS = F;
		vec3 kD = vec3(1.0) - kS;
		kD *= 1.0 - specular.g;

		diffuse_sun += (kD * color * PI + brdf) * max(0.0, NdotL) * (1.0 - shade);
		//diffuse_sun += no / denominator * diffuse_sun * max(dot(worldLightPos, normal), 0.0);
		// PBR specular, Red & Green reversed
		// Spec is in composite1.fsh
		diffuse_torch *= 1.0 - specular.r * 0.43;
		//diffuse_torch *= 1.0 + specular.b;

		vec3 diffuse = diffuse_sun + diffuse_torch;

		// AO
		#ifdef AO_Enabled
		float ao = blurAO(compositetex.g, normal);
		color *= ao;
		#endif

		#ifdef GlobalIllumination
		diffuse += blurGI(texture(gaux4, texcoord).rgb) * 0.5;
		#endif
		float simulatedGI = 0.1 + 1.7 * mclight.y;
		color = color * diffuse + color * ambientColor * simulatedGI;

		color = mix(fogcolor, color, clamp((512.0 - cdepth) / (512.0 - 32.0), 0.0, 1.0));
		#ifdef CrespecularRays
		float vl = texture(composite, texcoord * 0.5).b;
		vl += texture(composite, texcoord * 0.5, 1.0).b;
		vl += texture(composite, texcoord * 0.5 + vec2(0.0005, 0.0)).b;
		vl += texture(composite, texcoord * 0.5 + vec2(-0.0005, 0.0)).b;
		vl += texture(composite, texcoord * 0.5 + vec2(0.0, 0.0005)).b;
		vl += texture(composite, texcoord * 0.5 + vec2(0.0, -0.0005)).b;
		vl /= 6.0;

		vl = 1.0 - (1.0 / (1.0 + vl) - 0.5) * 2.0;
		vl *= (1.0 - extShadow);

		color = mix(color, suncolor, vl * max(0.0, 1.0 - eyebrightness * 0.1 * luma(suncolor)) * max(0.0, dot(nvpos, lightPosition)));
		#endif
	}

/* DRAWBUFFERS:35 */
	gl_FragData[0] = vec4(color, 1.0);
	gl_FragData[1] = vec4(mclight, shade, flag);
}
