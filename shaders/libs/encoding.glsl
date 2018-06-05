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

const float airFlag = 0.0f;
const float skyObjectFlag = 0.02f;

bool maskFlag(float16_t f0, float16_t f1) {
	return abs(f0 - f1) < 0.005;
}

f16vec3 normalDecode(f16vec2 enc) {
	f16vec4 nn = f16vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float16_t l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));
}

f16vec2 normalEncode(f16vec3 n) {
	f16vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
	enc = enc*0.5+0.5;
	return enc;
}

