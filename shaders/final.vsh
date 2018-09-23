#version 120
#include "compat.glsl"
#pragma optimize (on)

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

varying vec2 tex;

#define _VERTEX_SHADER_
#include "Utilities.glsl.frag"

#define LENS_FLARE
#ifdef LENS_FLARE
varying float sunVisibility;
varying vec2 lf1Pos;
varying vec2 lf2Pos;
varying vec2 lf3Pos;
varying vec2 lf4Pos;

#define LF1POS -0.3
#define LF2POS 0.5
#define LF3POS 0.7

uniform float viewWidth;
uniform float viewHeight;
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;
uniform sampler2D depthtex0;

#endif

//#define DISTORTION_FIX
#ifdef DISTORTION_FIX
const float strength = 1.0;
const float cylindricalRatio = 1.0;
uniform float aspectRatio;

uniform bool isEyeInWater;

varying vec3 vUV;
varying vec2 vUVDot;
#endif

void main() {
	gl_Position = ftransform();
	tex = gl_MultiTexCoord0.st;

	calcCommons();
	
	#ifdef DISTORTION_FIX
	float fov = atan(1./gbufferProjection[1][1]);
	if (isEyeInWater) fov *= 0.85;
	float height = tan(fov / aspectRatio * 0.5);
	
	float scaledHeight = strength * height;
	float cylAspectRatio = aspectRatio * cylindricalRatio;
	float aspectDiagSq = aspectRatio * aspectRatio + 1.0;
	float diagSq = scaledHeight * scaledHeight * aspectDiagSq;
	vec2 signedUV = (2.0 * tex + vec2(-1.0, -1.0));
 
	float z = 0.5 * sqrt(diagSq + 1.0) + 0.5;
	float ny = (z - 1.0) / (cylAspectRatio * cylAspectRatio + 1.0);
 
	vUVDot = sqrt(ny) * vec2(cylAspectRatio, 1.0) * signedUV;
	vUV = vec3(0.5, 0.5, 1.0) * z + vec3(-0.5, -0.5, 0.0);
	vUV.xy += tex;
	#endif
	
	// LF
	#ifdef LENS_FLARE
	vec4 ndcSunPosition = gbufferProjection * vec4(normalize(sunPosition), 1.0);
	ndcSunPosition /= ndcSunPosition.w;
	vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);	
	sunVisibility = 0.0f;
	vec2 screenSunPosition = vec2(-10.0);
	lf1Pos = lf2Pos = lf3Pos = lf4Pos = vec2(-10.0);
	if(ndcSunPosition.x >= -1.0 && ndcSunPosition.x <= 1.0 &&
		ndcSunPosition.y >= -1.0 && ndcSunPosition.y <= 1.0 &&
		ndcSunPosition.z >= -1.0 && ndcSunPosition.z <= 1.0) {
		screenSunPosition = ndcSunPosition.xy * 0.5 + 0.5;
		for(int x = -4; x <= 4; x++) {
			for(int y = -4; y <= 4; y++) {
				float depth = texture2DLod(depthtex0, screenSunPosition.st + vec2(float(x), float(y)) * pixelSize, 0.0).r;
				sunVisibility += float(depth > 0.9999) / 81.0;
			}
		}
		float shortestDis = min( min(screenSunPosition.s, 1.0 - screenSunPosition.s),
								 min(screenSunPosition.t, 1.0 - screenSunPosition.t));
		sunVisibility *= smoothstep(0.0, 0.2, clamp(shortestDis, 0.0, 0.2));
		
		vec2 dir = vec2(0.5) - screenSunPosition;
		lf1Pos = vec2(0.5) + dir * LF1POS;
		lf2Pos = vec2(0.5) + dir * LF2POS;
		lf3Pos = vec2(0.5) + dir * LF3POS;
	}
	#endif
}
