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

varying vec3 worldLightPosition;

#define AT_LSTEP
#include "libs/atmosphere.glsl"

void functions() {
	worldLightPosition = mat3(gbufferModelViewInverse) * normalize(sunPosition);
	float f = pow(max(abs(worldLightPosition.y) - 0.05, 0.0), 0.9) * 10.0;
	sunraw = texture2D(gaux4, project_skybox2uv(worldLightPosition)).rgb * (1.0 - cloud_coverage * 0.999) + vec3(0.03, 0.035, 0.05) * max(-worldLightPosition.y, 0.0) * 0.1 * (1.0 - cloud_coverage * 0.8);
	sunLight = (sunraw) * f;

	ambientU = texture2D(gaux4, vec2(0.0,  0.25)).rgb * 0.3;
}

#define Functions
#include "libs/DeferredCommon.vert"
