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

varying vec3 ambientU_noC;

#define AT_LSTEP
#include "libs/atmosphere.glsl"

varying vec3 worldLightPosition;

/*
0.0 1.0 0.0
1.0 0.1 0.0
-1.0 0.1 0.0
0.0 0.1 1.0
0.0 0.1 -1.0
*/

void functions() {
	worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);
	float f = pow(max(abs(worldLightPosition.y) - 0.05, 0.0), 0.9) * 10.0;
	sunraw = texture2D(gaux4, project_skybox2uv(worldLightPosition)).rgb * (1.0 - cloud_coverage * 0.999);
	sunLight = (sunraw) * f * vec3(1.2311, 1.0, 0.8286);

	ambientU = texture2D(gaux4, vec2(0.0,  0.5    )).rgb * 0.3;
	ambient0 = texture2D(gaux4, vec2(0.0,  0.26586)).rgb * 0.3;
	ambient1 = texture2D(gaux4, vec2(0.5,  0.26586)).rgb * 0.3;
	ambient2 = texture2D(gaux4, vec2(0.25, 0.26586)).rgb * 0.3;
	ambient3 = texture2D(gaux4, vec2(0.75, 0.26586)).rgb * 0.3;
	ambientD = (ambientU + ambient0 + ambient1 + ambient2 + ambient3) * 0.2;

	ambientU_noC = scatter(vec3(0., 25e2, 0.), vec3( 0.0,  1.0,  0.0), worldLightPosition, Ra) * 0.8;
}

#define Functions
#include "libs/DeferredCommon.vert"
