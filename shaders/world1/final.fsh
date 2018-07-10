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

varying vec2 uv;

const int RGBA8 = 0, R11_G11_B10 = 1, RGB16 = 2, RGBA16F = 3, RGBA16 = 4, RGB8 = 5, R32F = 6;

const int colortex0Format = RGBA16;
const int colortex1Format = RGBA8;
const int colortex2Format = RGBA16;
const int colortex3Format = RGB8;
const int gaux1Format = RGB16;
const int gaux2Format = RGB16;
const int gaux3Format = RGB16;
const int gaux4Format = R32F;

const int noiseTextureResolution = 256;

const float eyeBrightnessHalflife = 19.0f;
const float wetnessHalflife = 400.0f;
const float drynessHalflife = 20.0f;
const float centerDepthHalflife = 3.0f;

#include "GlslConfig"

//#define VIGNETTE
#define BLOOM
#define MOTION_BLUR

//#define FILMIC_CINEMATIC

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/Effects.glsl"
#include "libs/Lighting.frag"

uniform float screenBrightness;
uniform float nightVision;
uniform float blindness;
uniform float valHurt;

#define RAIN_SCATTER

//#define DISTORTION_FIX
#ifdef DISTORTION_FIX
varying vec3 vUV;
varying vec2 vUVDot;
#endif

varying vec3 sunLight;
varying vec3 worldLightPosition;

#define HURT_INDICATOR

void main() {
	#ifdef DISTORTION_FIX
	vec3 distort = dot(vUVDot, vUVDot) * vec3(-0.5, -0.5, -1.0) + vUV;
	vec2 uv_adj = distort.xy / distort.z;
	#else
	vec2 uv_adj = uv;
	#endif

	#ifndef EIGHT_BIT
	vec3 color = texture2D(colortex0, uv_adj).rgb;
	#else
	vec3 color;
	bit8(colortex0, uv_adj, color);
	#endif
	

	#ifdef NOISE_AND_GRAIN
	noise_and_grain(color);
	#endif
	
	color = pow(color, vec3(1.0 - nightVision * 0.5));
	color *= 1.0 - blindness * 0.9;
	
	vec2 uv_n = uv * 0.4;
	vec2 central = vec2(0.5) - uv_n;
	float screwing = noise_tex(uv_n - frameTimeCounter * central);
	uv_n += screwing * 0.04 * central;
	screwing += noise_tex(uv_n * 2.5 + frameTimeCounter * 0.4 * central);
	uv_n += screwing * 0.08 * central;
	screwing += noise_tex(uv_n * 8.0 - frameTimeCounter * 0.8 * central);
	
	//color = saturation(color, 1.2);

	#ifdef HURT_INDICATOR
	color = vignette(color, vec3(0.4, 0.00, 0.00), min(1.0, valHurt * fma(max(0.0, screwing), 0.25, 0.75)));
	#endif

	ACEStonemap(color, (screenBrightness * 0.5 + 1.0) * exposure);

	#ifdef FILMIC_CINEMATIC
	filmic_cinematic(color);
	#endif
	
	gl_FragColor = vec4(toGamma(color),1.0);
}