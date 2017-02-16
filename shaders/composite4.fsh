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

uniform sampler2D composite;

in vec2 texcoord;

#define BLOOM
#ifdef BLOOM
const bool compositeMipmapEnabled = true;

#define luma(color)	dot(color,vec3(0.2126, 0.7152, 0.0722))
const float offset[9] = float[] (0.0, 1.4896, 3.4757, 5.4619, 7.4482, 9.4345, 11.421, 13.4075, 15.3941);
const float weight[9] = float[] (0.4210103, 0.191235, 0.06098, 0.0238563, 0.0093547, 0.0030827, 0.000801, 0.000163, 0.000078);

#define blurLoop(i) a = texture(composite, texcoord + vec2(0.0019, .0) * offset[i], 1.0).rgb; color += a * luma(a) * weight[i]; a = texture(composite, texcoord - vec2(0.0019, .0) * offset[i], 1.0).rgb; color += a * luma(a) * weight[i];

vec3 bloom() {
	vec3 color = texture(composite, texcoord).rgb * weight[0];
	vec3 a;
	blurLoop(1)
	blurLoop(2)
	blurLoop(3)
	blurLoop(4)
	blurLoop(5)
	blurLoop(6)
	blurLoop(7)
	blurLoop(8)
	return color;
}

#endif

//#define SSEDAA
#ifdef SSEDAA
uniform float viewWidth;
uniform float viewHeight;
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
	#ifdef BLOOM
	gl_FragData[0] = vec4(bloom(), 1.0);
	#endif

	#ifdef SSEDAA
	gl_FragData[1] = EDAA();
	#else
	gl_FragData[1] = texture(composite, texcoord);
	#endif
}
