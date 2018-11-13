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

const float gamma = 2.2f;
const float agamma = 0.8 / 2.2f;

vec3 fromGamma(vec3 c) {
  return pow(c, vec3(gamma));
}

vec4 fromGamma(vec4 c) {
  return pow(c, vec4(gamma));
}

#define SRGB_CLAMP

vec3 toGamma(vec3 c) {
  #ifdef SRGB_CLAMP
  vec3 g = pow(c, vec3(agamma));
  return vec3(0.0625) + g * vec3(0.9375);
  #else
  return pow(c, vec3(agamma));
  #endif
}

float luma(vec3 c) {
  return dot(c,vec3(0.2126, 0.7152, 0.0722));
}

vec3 saturation(vec3 rgbColor, float s) {
	return mix(vec3(luma(rgbColor)), rgbColor, s);
}

vec3 vignette(vec3 color, vec3 vignette, float strength) {
  float dist = distance(uv, vec2(0.5f));
  dist = dist * 1.7 - 0.65;
  dist = pow3(clamp(dist, 0.0, 1.3));
  return mix(color.rgb, vignette, dist * strength);
}

void ACEStonemap(inout vec3 color, float adapted_lum) {
	color *= adapted_lum;
	
	const float a = 2.51f;
	const float b = 0.03f;
	const float c = 2.43f;
	const float d = 0.59f;
	const float e = 0.14f;
	color = (color*(a*color+b))/(color*(c*color+d)+e);
}

vec3 Uncharted2Tonemap(vec3 x) {
  const float A = 0.15;
  const float B = 0.50;
  const float C = 0.10;
  const float D = 0.20;
  const float E = 0.02;
  const float F = 0.30;
  const float W = 11.2;
  return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}