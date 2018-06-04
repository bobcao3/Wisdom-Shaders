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

varying vec3 sunLight;
varying vec3 sunraw;

varying vec3 ambientU;
varying vec3 ambient0;
varying vec3 ambient1;
varying vec3 ambient2;
varying vec3 ambient3;
varying vec3 ambientD;

#define AT_LSTEP
#include "libs/atmosphere.glsl"

//#define TAA
#ifdef TAA
#include "libs/TAAjitter.glsl"
#endif

varying vec3 worldLightPosition;

void functions() {
	worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);
	float f = pow(abs(worldLightPosition.y), 0.9) * (9.0 - wetness * 8.7);
	sunraw = scatter(vec3(0., 25e2, 0.), worldLightPosition, worldLightPosition, Ra) + vec3(0.03, 0.035, 0.05) * max(-worldLightPosition.y, 0.0) * 0.1;
	sunLight = (sunraw) * f;

	ambientU = scatter(vec3(0., 25e2, 0.), vec3( 0.0,  1.0,  0.0), worldLightPosition, Ra) * 0.8;
	ambient0 = scatter(vec3(0., 25e2, 0.), normalize(vec3( 1.0,  0.1,  0.0)), worldLightPosition, Ra) * 0.8;
	ambient1 = scatter(vec3(0., 25e2, 0.), normalize(vec3(-1.0,  0.1,  0.0)), worldLightPosition, Ra) * 0.8;
	ambient2 = scatter(vec3(0., 25e2, 0.), normalize(vec3( 0.0,  0.1,  1.0)), worldLightPosition, Ra) * 0.8;
	ambient3 = scatter(vec3(0., 25e2, 0.), normalize(vec3( 0.0,  0.1, -1.0)), worldLightPosition, Ra) * 0.8;
	ambientD = (ambientU + ambient0 + ambient1 + ambient2 + ambient3) * 0.2 + 0.007;

	#ifdef TAA
	//gl_Position.xyz /= gl_Position.w;
	//TemporalAntiJitterProjPos(gl_Position);
	//gl_Position.xyz *= gl_Position.w;
	#endif
}

#define Functions
#include "libs/DeferredCommon.vert"
