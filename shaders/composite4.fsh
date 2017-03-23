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

uniform sampler2D composite;

varying vec2 texcoord;

#define BLOOM
#ifdef BLOOM
#define BLUR
#endif

#define DOF
#ifdef DOF
#define BLUR
#endif

#define RAINFOG
#ifdef RAINFOG
#define BLUR
#endif

uniform float viewWidth;
uniform float viewHeight;

#ifdef BLUR
const float padding = 0.02f;
const bool compositeMipmapEnabled = true;

bool checkBlur(vec2 offset, float scale) {
	return
	(  (texcoord.s - offset.s + padding < 1.0f / scale + (padding * 2.0f))
	&& (texcoord.t - offset.t + padding < 1.0f / scale + (padding * 2.0f)) );
}

vec3 LODblur(in int LOD, in vec2 offset) {
	float scale = exp2(LOD);
	vec3 bloom = vec3(0.0);

	float allWeights = 0.0f;

	for (int i = 0; i < 5; i++) {
		for (int j = 0; j < 5; j++) {

			float weight = 1.0f - distance(vec2(i, j), vec2(2.5f)) * 0.72;
			weight = clamp(weight, 0.0f, 1.0f);
			weight = 1.0f - cos(weight * 3.1415 * 0.5f);
			weight = pow(weight, 2.0f);
			vec2 coord = vec2(i - 2.5, j - 2.5) / vec2(viewWidth, viewHeight);

			vec2 finalCoord = (texcoord.st + coord.st - offset.st) * scale;

			if (weight > 0.0f) {
				bloom += clamp(texture2DLod(composite, finalCoord, LOD / 2).rgb, vec3(0.0f), vec3(1.0f)) * weight;
				allWeights += 1.0f * weight;
			}
		}
	}

	return bloom / allWeights;
}
#endif

//#define SSEDAA
#ifdef SSEDAA
uniform sampler2D depthtex0;
uniform sampler2D gdepth;
uniform float far;

ivec2 px = ivec2(texcoord * vec2(viewWidth, viewHeight));

bool detect_edge(in ivec2 ifpx) {
	float depth0 = texelFetch(depthtex0, ifpx, 0).r;
	float depth1 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,1)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,2)).r * 0.1;
	float depth2 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,-1)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,-2)).r * 0.1;
	float depth3 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(1,0)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(2,0)).r * 0.1;
	float depth4 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(-1,0)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(-2,0)).r * 0.1;

	float edge0 = 0.0;
	edge0 += float(depth0 > depth1);
	edge0 -= float(depth0 < depth1);
	float edge1 = 0.0;
	edge1 += float(depth0 > depth2);
	edge1 -= float(depth0 < depth2);
	float edge2 = 0.0;
	edge2 += float(depth0 > depth3);
	edge2 -= float(depth0 < depth3);
	float edge3 = 0.0;
	edge3 += float(depth0 > depth4);
	edge3 -= float(depth0 < depth4);

	bool isedge = abs(edge0 + edge1 + edge2 + edge3) > 1.43;

	return isedge;
}

vec4 EDAA() {
	float ldepth = 1.0 - length(texelFetch(gdepth, px, 0)) / far;

	vec4 orgcolor = texelFetch(composite, px, 0);
	bool edge0 = detect_edge(px);
	bool edge1 = detect_edge(px + ivec2(1,0));
	bool edge2 = detect_edge(px + ivec2(-1,0));
	bool edge3 = detect_edge(px + ivec2(0,1));
	bool edge4 = detect_edge(px + ivec2(0,-1));

	vec4 color = orgcolor;
	float bias = 0.1 * ldepth;
	if (edge1 && edge3) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(1,0)), bias);
	}
	if (edge2 && edge4) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,-1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(-1,0)), bias);
	}
	if (edge1 && edge4) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,-1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(1,0)), bias);
	}
	if (edge2 && edge3) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(-1,0)), bias);
	}
	if (edge0) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,1)), bias * 2.0);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,-1)), bias * 2.0);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(1,0)), bias * 2.0);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(-1,0)), bias * 2.0);
	}

	return color;
}

#endif

/* DRAWBUFFERS:03 */
void main() {
	#ifdef BLUR
	vec3 blur = vec3(0.0);
	float lod = 2.0; vec2 offset = vec2(0.0f);
	if (texcoord.y < 0.25 + padding * 2.0 + 0.6251 && texcoord.x < 0.0078125 + 0.25f + 0.100f) {
		if (texcoord.y > 0.25 + padding) {
			     if (checkBlur(offset = vec2(0.0f, 0.25f)     + vec2(0.000f, 0.025f), exp2(lod = 3.0))) {}
			else if (checkBlur(offset = vec2(0.125f, 0.25f)   + vec2(0.025f, 0.025f), exp2(lod = 4.0))) {}
			else if (checkBlur(offset = vec2(0.1875f, 0.25f)  + vec2(0.050f, 0.025f), exp2(lod = 5.0))) {}
			else if (checkBlur(offset = vec2(0.21875f, 0.25f) + vec2(0.075f, 0.025f), exp2(lod = 6.0))) {}
			else lod = 0.0f;
		} else if (texcoord.x > 0.25 + padding) lod = 0.0f;
		if (lod > 1.0f) blur = LODblur(int(lod), offset);
	}
	gl_FragData[0] = vec4(blur, 1.0);
	#endif

	#ifdef SSEDAA
	gl_FragData[1] = EDAA();
	#else
	gl_FragData[1] = texture2D(composite, texcoord);
	#endif
}
