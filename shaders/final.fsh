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

#version 120
#extension GL_ARB_shader_texture_lod : require
#pragma optimize(on)

const int RGB8 = 0, RGBA32F = 1, RGB16 = 2, RGBA16 = 3, RGBA8 = 4;
#define GAlbedo colortex0
#define GWPos colortex1
#define GNormals gnormal
#define Output composite
#define GSpecular gaux1
#define mcData gaux2
#define WaterWPos gaux3

const float centerDepthHalflife = 2.5f;
uniform float centerDepthSmooth;

const int colortex0Format = RGBA16;
const int colortex1Format = RGBA32F;
const int gnormalFormat = RGBA16;
const int compositeFormat = RGB16;
const int gaux1Format = RGBA8;
const int gaux2Format = RGBA8;
const int gaux3Format = RGBA32F;
const int gaux4Format = RGBA8;

varying vec2 texcoord;

uniform sampler2D depthtex0;
uniform sampler2D Output;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D GWPos;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform float viewHeight;
uniform float viewWidth;
uniform float near;
uniform float far;
uniform float aspectRatio;
uniform float rainStrength;

const float gamma = 2.2;

#define luma(color)	dot(color,vec3(0.2126, 0.7152, 0.0722))

varying float centerDepth;

#define DOF_NEARVIEWBLUR
#define DOF

#define linearizeDepth(depth) (2.0 * near) / (far + near - depth * (far - near))

#define MOTION_BLUR

#ifdef MOTION_BLUR
uniform mat4 gbufferModelViewInverse;
uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform mat4 gbufferProjectionInverse;

#define MOTIONBLUR_MAX 0.1
#define MOTIONBLUR_STRENGTH 0.5
#define MOTIONBLUR_SAMPLE 12

vec3 motionBlur(vec3 color, in vec2 uv, in vec4 viewPosition) {
	vec4 worldPosition = gbufferModelViewInverse * viewPosition + vec4(cameraPosition, 0.0);
	vec4 prevClipPosition = gbufferPreviousProjection * gbufferPreviousModelView * (worldPosition - vec4(previousCameraPosition, 0.0));
	vec4 prevNdcPosition = prevClipPosition / prevClipPosition.w;
	vec2 prevUv = (prevNdcPosition * 0.5 + 0.5).st;
	vec2 delta = uv - prevUv;
	float dist = length(delta) * 0.25;
	delta = normalize(delta);
	dist = min(dist, MOTIONBLUR_MAX);
	int num_sams = int(dist / MOTIONBLUR_MAX * MOTIONBLUR_SAMPLE) + 1;
	dist *= MOTIONBLUR_STRENGTH;
	delta *= dist / float(MOTIONBLUR_SAMPLE);
	for(int i = 1; i < num_sams; i++) {
		uv += delta;
		color += texture2D(Output, uv).rgb;
	}
	color /= float(num_sams);
	return color;
}
#endif

vec3 vignette(vec3 color) {
	float dist = distance(texcoord.st, vec2(0.5f));
	dist = clamp(dist * 1.9 - 0.75, 0.0, 1.0);
	dist = smoothstep(0.0, 1.0, dist);
	return color.rgb * (1.0 - dist);
}

varying vec3 suncolor;
uniform ivec2 eyeBrightnessSmooth;
float exposure = 4.0 * clamp(1.0 - clamp(eyeBrightnessSmooth.y / 240.0 * 0.6 * luma(suncolor), 0.0, 1.0), 0.0, 1.0);

#define BLOOM

#ifdef BLOOM
#define texture_Bicubic(tex, i) texture2D(tex, i)

vec3 bloom() {
	vec2 tex_offset = vec2(1.0f / viewWidth, 1.0f / viewHeight);

	vec2 tex = (texcoord.st - tex_offset * 0.5f) * 0.25;
	vec3 color = texture_Bicubic(gcolor, tex).rgb;
	tex = (texcoord.st - tex_offset * 0.5f) * 0.125      + vec2(0.0f, 0.25f)	  + vec2(0.000f, 0.025f);
	color +=  texture_Bicubic(gcolor, tex).rgb * 0.65;
	tex = (texcoord.st - tex_offset * 0.5f) * 0.0625     + vec2(0.125f, 0.25f)  + vec2(0.025f, 0.025f);
	color +=  texture_Bicubic(gcolor, tex).rgb * 0.55;
	tex = (texcoord.st - tex_offset * 0.5f) * 0.03125    + vec2(0.1875f, 0.25f)	+ vec2(0.050f, 0.025f);
	color +=  texture_Bicubic(gcolor, tex).rgb * 0.35;
	tex = (texcoord.st - tex_offset * 0.5f) * 0.015625   + vec2(0.21875f, 0.25f)+ vec2(0.075f, 0.025f);
	color +=  texture_Bicubic(gcolor, tex).rgb * 0.29;
	tex = (texcoord.st - tex_offset * 0.5f) * 0.0078125  + vec2(0.25f, 0.25f)   + vec2(0.100f, 0.025f);
	color +=  texture_Bicubic(gcolor, tex).rgb * 0.27;

	color *= 0.2;
	color *= 1.0 + exposure;
	return color * luma(color);
}
#endif

const float A = 0.13; // brightness multiplier
const float B = 0.45; // black level
const float C = 0.125; // constrast level
const float D = 0.20;
const float E = 0.02;
const float F = 0.30;
const float W = 11.2;

#define Uncharted2Tonemap(x) (((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F)

void colorAdjust(inout vec3 c) {
	c *= 1.5 + exposure;

	const float ExposureBias = 2.0f;
	vec3 curr = Uncharted2Tonemap(ExposureBias * c);

	vec3 whiteScale = 1.0f / Uncharted2Tonemap(vec3(W));
	vec3 color = curr * whiteScale;

	c = pow(color, vec3(1.f/2.2f));

	// Saturation
	float l = dot(c, vec3(0.0, 0.3, 0.3));
	vec3 chroma = c - l;
	c = (chroma * 1.2) + l;
}

varying float sunVisibility;
varying vec2 lf1Pos;
varying vec2 lf2Pos;
varying vec2 lf3Pos;
varying vec2 lf4Pos;

#define MANHATTAN_DISTANCE(DELTA) abs(DELTA.x)+abs(DELTA.y)

#define LENS_FLARE(COLOR, UV, LFPOS, LFSIZE, LFCOLOR) { vec2 delta = UV - LFPOS; delta.x *= aspectRatio; if(MANHATTAN_DISTANCE(delta) < LFSIZE * 2.0) { float d = max(LFSIZE - sqrt(dot(delta, delta)), 0.0); COLOR += LFCOLOR.rgb * LFCOLOR.a * smoothstep(0.0, LFSIZE, d) * sunVisibility;} }

#define LF1SIZE 0.1
#define LF2SIZE 0.15
#define LF3SIZE 0.25
#define LF4SIZE 0.25

const vec4 LF1COLOR = vec4(1.0, 1.0, 1.0, 0.1);
const vec4 LF2COLOR = vec4(0.42, 0.0, 1.0, 0.1);
const vec4 LF3COLOR = vec4(0.0, 1.0, 0.0, 0.1);
const vec4 LF4COLOR = vec4(1.0, 0.0, 0.0, 0.1);

vec3 lensFlare(vec3 color) {
	if(sunVisibility <= 0.0)
	return color;
	LENS_FLARE(color, texcoord, lf1Pos, LF1SIZE, LF1COLOR);
	LENS_FLARE(color, texcoord, lf2Pos, LF2SIZE, LF2COLOR);
	LENS_FLARE(color, texcoord, lf3Pos, LF3SIZE, LF3COLOR);
	LENS_FLARE(color, texcoord, lf4Pos, LF4SIZE, LF4COLOR);
	return color;
}

#define RAINFOG

void main() {
	vec3 color = texture2D(Output, texcoord).rgb;

	#ifdef MOTION_BLUR
	vec4 viewpos = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, texture2D(depthtex0, texcoord).r * 2.0 - 1.0, 1.0f);
	viewpos /= viewpos.w;
	if (texture2D(gaux2, texcoord).a > 0.11) color = motionBlur(color, texcoord, viewpos);
	#endif

	float depth = texture2D(depthtex0, texcoord).r;
	float ldepthN = linearizeDepth(depth);

	vec2 pix_offset = vec2(1.0f / viewWidth, 1.0f / viewHeight) * 0.5f;
	vec3 blur = texture2D(gcolor, (texcoord.st - pix_offset) * 0.25).rgb;
	#ifdef DOF
	#ifdef DOF_NEARVIEWBLUR
	float pcoc = abs(ldepthN - linearizeDepth(centerDepth));
	#else
	float pcoc = max(0.0, ldepthN - linearizeDepth(centerDepth));
	#endif

	color = mix(color, blur, pcoc);
	#endif

	// Rain scatter fog
	#ifdef RAINFOG
	color = mix(color, blur, (ldepthN * 0.9 + 0.1) * rainStrength);
	#endif

	#ifdef BLOOM
	color += bloom();
	#endif

	color = lensFlare(color);

	color = vignette(color);
	colorAdjust(color);

	gl_FragColor = vec4(color, 1.0f);
}
