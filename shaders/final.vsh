#version 120
#include "libs/compat.glsl"
#pragma optimize(on)

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

//#define DISTORTION_FIX
#ifdef DISTORTION_FIX
const float strength = 1.0;
const float cylindricalRatio = 1.0;

varying vec3 vUV;
varying vec2 vUVDot;
#endif

#define AT_LSTEP
#include "libs/atmosphere.glsl"

varying vec2 uv;

varying vec3 sunLight;
varying vec3 worldLightPosition;

void main() {
	gl_Position = ftransform();

	uv = gl_MultiTexCoord0.st;
  
	worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);
	float f = pow(max(abs(worldLightPosition.y) - 0.05, 0.0), 0.9) * 10.0;
	sunLight = (texture2D(gaux4, project_skybox2uv(worldLightPosition)).rgb * (1.0 - cloud_coverage * 0.999) + vec3(0.03, 0.035, 0.05) * max(-worldLightPosition.y, 0.0) * 0.1 * (1.0 - cloud_coverage * 0.8))* f;

	#ifdef DISTORTION_FIX
	float fov = atan(1./gbufferProjection[1][1]);
	float height = tan(fov / aspectRatio * 0.5);

	float scaledHeight = strength * height;
	float cylAspectRatio = aspectRatio * cylindricalRatio;
	float aspectDiagSq = aspectRatio * aspectRatio + 1.0;
	float diagSq = scaledHeight * scaledHeight * aspectDiagSq;
	vec2 signedUV = (2.0 * uv + vec2(-1.0, -1.0));

	float z = 0.5 * sqrt(diagSq + 1.0) + 0.5;
	float ny = (z - 1.0) / (cylAspectRatio * cylAspectRatio + 1.0);

	vUVDot = sqrt(ny) * vec2(cylAspectRatio, 1.0) * signedUV;
	vUV = vec3(0.5, 0.5, 1.0) * z + vec3(-0.5, -0.5, 0.0);
	vUV.xy += uv;
	#endif
}
