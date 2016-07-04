// Copyright 2016 bobcao3 <bobcaocheng@163.com>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#version 130

uniform int fogMode;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform float wetness;
uniform float frameTimeCounter;

in vec4 color;
in vec4 texcoord;
in float iswater;
in vec4 lmcoord;
in vec3 wpos;
in vec2 normal;
/* DRAWBUFFERS:054 */

#define PI 3.14

void main() {
	if (iswater > 0.5) {
		vec4 watercolor = vec4(0.27,0.50,0.70,0.15+ (wetness / 3));

		gl_FragData[0] = vec4((watercolor*color).rgb, watercolor.a);
		gl_FragData[2] = vec4(lmcoord.t, 0.125, lmcoord.s, 1.0);
	} else {
		gl_FragData[0] = texture2D(texture, texcoord.xy)*color;
		gl_FragData[2] = vec4(lmcoord.t, 0.9, lmcoord.s, 1.0);
	}
	if(fogMode == 9729)
		gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp((gl_Fog.end - gl_FogFragCoord) / (gl_Fog.end - gl_Fog.start), 0.0, 1.0));
	else if(fogMode == 2048)
		gl_FragData[0].rgb = mix(gl_Fog.color.rgb, gl_FragData[0].rgb, clamp(exp(-gl_FogFragCoord * gl_Fog.density), 0.0, 1.0));
	gl_FragData[1] = vec4(normal, 0.0, 1.0);
}
