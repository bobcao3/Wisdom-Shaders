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
#include "compat.glsl"


varying vec2 texcoord;

uniform sampler2D composite;
uniform sampler2D colortex10;

const bool compositeMipmapEnabled = true;

uniform float viewWidth;
uniform float viewHeight;

float luma(in vec3 color) { return dot(color,vec3(0.2126, 0.7152, 0.0722)); }

void compositeWeather(inout vec4 color) {
	vec4 packedWeather = texture2D(colortex10, texcoord.xy);
	float coverage = packedWeather.a;
	if (coverage <= 1.0 / 255.0) return;

	float emissiveCoverage = clamp(packedWeather.r, 0.0, 1.0);
	vec3 packedData = packedWeather.rgb / coverage;
	float emissive = clamp(packedData.r, 0.0, 1.0);
	float Y = packedData.g;
	float Cb = packedData.b;
	const float Kr = 0.2126;
	const float Kb = 0.0722;
	float weatherR = Y;
	float weatherB = Y + (Cb - 0.5) * 2.0 * (1.0 - Kb);
	float weatherG = (Y - Kr * weatherR - Kb * weatherB) / (1.0 - Kr - Kb);
	vec3 weatherColor = pow(max(vec3(weatherR, weatherG, weatherB), vec3(0.0)), vec3(2.2));

	float rainCoverage = coverage * (1.0 - emissive);
	if (rainCoverage > 0.0) {
		vec3 broadScene = texture2DLod(composite, texcoord.xy, 4.0).rgb * 0.15;
		broadScene += texture2DLod(composite, texcoord.xy, 5.0).rgb * 0.30;
		broadScene += texture2DLod(composite, texcoord.xy, 6.0).rgb * 0.55;
		vec3 rainLit = weatherColor * (0.35 + 0.25 * luma(broadScene)) + broadScene * 0.45;
		float regionalBrightness = max(luma(broadScene), 0.0);
		float rainBrightness = max(luma(rainLit), 1e-5);
		rainLit *= min(1.0, 1.3 * regionalBrightness / rainBrightness);
		color.rgb = mix(color.rgb, color.rgb * 0.75 + rainLit, rainCoverage * 0.65);
	}

	float emissiveRamp = smoothstep(0.2, 0.85, emissiveCoverage);
	color.rgb += weatherColor * emissiveCoverage * emissiveRamp * 8.0;
}

//#define SSEDAA

/* DRAWBUFFERS:3 */
void main() {
	vec4 color = texture2D(composite, texcoord.xy);
	#ifdef SSEDAA
	vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);
	
	vec2 U = vec2(0.0, pixel.y);
	vec2 R = vec2(pixel.x, 0.0);

	float topHeight = luma(texture2D(composite, texcoord.xy+U).rgb);
	float bottomHeight = luma(texture2D(composite, texcoord.xy-U).rgb);
	float rightHeight = luma(texture2D(composite, texcoord.xy+R).rgb);
	float leftHeight = luma(texture2D(composite, texcoord.xy-R).rgb);
	float leftTopHeight = luma(texture2D(composite, texcoord.xy-R+U).rgb);
	float leftBottomHeight = luma(texture2D(composite, texcoord.xy-R-U).rgb);
	float rightTopHeight = luma(texture2D(composite, texcoord.xy+R+U).rgb);
	float rightBottomHeight = luma(texture2D(composite, texcoord.xy+R-U).rgb);
	
	float xDifference = (2.0 * rightHeight + rightTopHeight + rightBottomHeight) / 4.0f - (2.0 * leftHeight + leftTopHeight + leftBottomHeight) / 4.0f;
	float yDifference = (2.0 * topHeight + leftTopHeight + rightTopHeight) / 4.0f - (2.0 * bottomHeight + rightBottomHeight + leftBottomHeight) / 4.0f;
	vec3 V1 = vec3(1.0, 0.0, xDifference);
	vec3 V2 = vec3(0.0, 1.0, yDifference);
	vec3 Normal = normalize(cross(V1, V2));
	
	Normal.xy *= pixel;
	vec4 Scene1 = texture2D(composite, texcoord.xy + Normal.xy);
	vec4 Scene2 = texture2D(composite, texcoord.xy - Normal.xy);
	vec4 Scene3 = texture2D(composite, texcoord.xy + vec2(Normal.x, -Normal.y));
	vec4 Scene4 = texture2D(composite, texcoord.xy - vec2(Normal.x, -Normal.y));
	
	color = (color + Scene1 + Scene2 + Scene3 + Scene4) * 0.2f;
	#endif
	compositeWeather(color);
	gl_FragData[0] = color;
}
