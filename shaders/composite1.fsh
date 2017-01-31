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

#pragma optimize(on)

uniform sampler2D composite;
uniform sampler2D gdepth;
//uniform sampler2D gnormal;

invariant varying vec2 texcoord;

uniform float far;

vec3 vpos = texture2D(gdepth, texcoord).xyz;
float cdepth = length(vpos);
float dFar = 1.0 / far;
float cdepthN = cdepth * dFar;

#define saturate(x) clamp(0.0,x,1.0)

vec3 normalDecode(vec2 enc) {
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));
}

vec3 cNormal;

float blurAO(float c) {
	float a = c;
	// float rcdepth = texture2D(depthtex0, texcoord).r * 200.0f;
	 float d = 0.068 / cdepthN;
	vec3 vpos = texture2D(gdepth, texcoord).rgb;

	for (int i = -5; i < 0; i++) {
		vec2 adj_coord = texcoord + vec2(0.0015, 0.0) * i * d;
		vec3 nvpos = texture2D(gdepth, adj_coord).rgb;
		a += mix(texture2D(composite, adj_coord).g, c, saturate(distance(nvpos, vpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	for (int i = 1; i < 6; i++) {
		vec2 adj_coord = texcoord + vec2(-0.0015, 0.0) * i * d;
		vec3 nvpos = texture2D(gdepth, adj_coord).rgb;
		a += mix(texture2D(composite, adj_coord).g, c, saturate(distance(nvpos, vpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	return a * 0.1629;
}

//#define GlobalIllumination

#ifdef GlobalIllumination
uniform sampler2D gaux4;
vec3 blurGI(vec3 c) {
	vec3 a = c;
	// float rcdepth = texture2D(depthtex0, texcoord).r * 200.0f;
	 float d = 0.068 / cdepthN;
	vec3 vpos = texture2D(gdepth, texcoord).rgb;

	for (int i = -4; i < 0; i++) {
		vec2 adj_coord = texcoord + vec2(0.0035, 0.0) * i * d;
		vec3 nvpos = texture2D(gdepth, adj_coord).rgb;
		a += mix(texture2D(gaux4, adj_coord * 0.25).rgb, c, saturate(distance(nvpos, vpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	for (int i = 1; i < 5; i++) {
		vec2 adj_coord = texcoord + vec2(-0.0035, 0.0) * i * d;
		vec3 nvpos = texture2D(gdepth, adj_coord).rgb;
		a += mix(texture2D(gaux4, adj_coord * 0.25).rgb, c, saturate(distance(nvpos, vpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	return a * 0.1629;
}
#endif

void main() {
	vec4 ctex = texture2D(composite, texcoord);
	//cNormal = normalDecode(texture2D(gnormal, texcoord).rg);

	if (ctex.r > 0.21) {
		ctex.g = blurAO(ctex.g);
	}

/* DRAWBUFFERS:37 */
	gl_FragData[0] = ctex;
	#ifdef GlobalIllumination
	gl_FragData[1] = vec4(blurGI(texture2D(gaux4, texcoord * 0.25).rgb), 1.0);
	#endif
}
