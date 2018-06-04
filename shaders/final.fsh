#version 120

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

varying vec2 uv;

const int RGBA8 = 0, R11_G11_B10 = 1, R8 = 2, RGBA16F = 3, RGBA16 = 4, RGBA32F = 5;

const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA16;
const int colortex3Format = RGBA16;
const int gaux1Format = RGBA32F;
const int gaux2Format = RGBA16F;
const int gaux3Format = RGBA16F;
const int gaux4Format = RGBA16;

const int noiseTextureResolution = 256;

#include "GlslConfig"

//#define VIGNETTE
#define BLOOM

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/Effects.glsl"

uniform float screenBrightness;

#define DISTORTION_FIX
#ifdef DISTORTION_FIX
varying vec3 vUV;
varying vec2 vUVDot;
#endif

void main() {
	#ifdef DISTORTION_FIX
	vec3 distort = dot(vUVDot, vUVDot) * vec3(-0.5, -0.5, -1.0) + vUV;
	vec2 uv_adj = distort.xy / distort.z;
	#else
	vec2 uv_adj = uv;
	#endif

/*	vec3 color = applyEffect(1.0, 1.0,
		0.0, -0.2, 0.0,
		-0.2, 1.8, -0.2,
		0.0, -0.2, 0.0,
		gaux2, uv_adj);*/
	vec3 color = texture2D(gaux2, uv_adj).rgb;

	float exposure = 1.0;

	#ifdef BLOOM
	vec3 b = bloom(color, uv_adj);

	const vec2 tex = vec2(0.5) * 0.015625 + vec2(0.21875f, 0.3f) + vec2(0.090f, 0.035f);
	exposure = max(1.0 - luma(texture_Bicubic(colortex0, tex).rgb), 0.05) * 5.0;
	//#define BLOOM_DEBUG
	#ifdef BLOOM_DEBUG
	color = max(vec3(0.0), b) * exposure;
	#else
	color += max(vec3(0.0), b) * exposure;
	#endif
	#endif

	ACEStonemap(color, screenBrightness * 0.5 + 0.75);

	gl_FragColor = vec4(toGamma(color),1.0);
}
