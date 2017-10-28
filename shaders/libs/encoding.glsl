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

#include "compat.glsl"

const float transparentFlag = 0.7f;
const float iceFlag = 0.72f;
const float waterFlag = 0.74f;

const float terrianFlag = 0.3f;
const float foilage1Flag = 0.32f;
const float foilage2Flag = 0.34f;

const float entityFlag = 0.2f;

const float airFlag = 0.1f;
const float skyObjectFlag = 0.12f;

bool maskFlag(float16_t f0, float16_t f1) {
	return abs(f0 - f1) < 0.005;
}

f16vec3 normalDecode(f16vec2 encodedNormal) {
	encodedNormal = encodedNormal * 4.0 - 2.0;
	float16_t f = dot(encodedNormal, encodedNormal);
	float16_t g = sqrt(1.0 - f * 0.25);
	return vec3(encodedNormal * g, 1.0 - f * 0.5);
}

f16vec2 normalEncode(f16vec3 n) {
	return sqrt(-n.z * 0.125f + 0.125f) * normalize(n.xy) + 0.5f;
}
