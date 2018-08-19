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
#include "libs/compat.glsl"
#pragma optimize(on)

attribute vec4 mc_Entity;

varying float data;
varying vec2 uv;
varying vec3 vpos;

varying vec3 glcolor;

varying vec3 N;
varying vec3 worldLightPosition;

varying vec3 wN;
varying vec3 wT;
varying vec3 wB;

#define WATER_PARALLAX
#ifdef WATER_PARALLAX
varying vec3 tangentpos;
#endif

varying vec3 wpos;

#include "libs/encoding.glsl"

varying vec3 sunLight;
varying vec3 sunraw;
varying vec3 ambientU;

varying vec2 lmcoord;

#define AT_LSTEP
#include "libs/atmosphere.glsl"

attribute vec4 at_tangent;

void main() {
	data = (mc_Entity.x > 7.5 && mc_Entity.x < 9.5 || mc_Entity.y == 1.0) ? waterFlag : transparentFlag;
	if  (mc_Entity.x == 79.0) data = iceFlag;

	vec4 pos = gl_Vertex;
	pos = gl_ModelViewMatrix * pos;
	gl_Position = gl_ProjectionMatrix * pos;

	uv = (gl_TextureMatrix[0] * gl_MultiTexCoord0).st;
	vpos = pos.xyz;

	N = normalize(gl_NormalMatrix * gl_Normal);
	vec3 tangent = normalize(gl_NormalMatrix * at_tangent.xyz);

	wN = normalize(mat3(gbufferModelViewInverse) * N);
	wT = normalize(mat3(gbufferModelViewInverse) * tangent);
	wB = cross(wT, wN);

	// ===============
	worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);
	float f = pow(max(abs(worldLightPosition.y) - 0.05, 0.0), 0.9) * 5.0;
	sunraw = texture2D(gaux4, project_skybox2uv(worldLightPosition)).rgb * (1.0 - cloud_coverage * 0.9);
	sunLight = (sunraw) * f;

	ambientU = texture2D(gaux4, vec2(0.0, 0.25)).rgb * 4.0;

	lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

	vec4 p = gbufferModelViewInverse * vec4(vpos, 1.0);
	wpos = p.xyz / p.w;

	#ifdef WATER_PARALLAX
	mat3 TBN = mat3(tangent, cross(tangent, N), N);
	tangentpos = normalize(vpos * TBN);
	#endif

	glcolor = gl_Color.rgb;
}
