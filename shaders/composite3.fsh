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
#extension GL_ARB_shader_texture_lod : require

#define BLOOM

const bool gdepthMipmapEnabled = true;

uniform sampler2D gcolor;
uniform sampler2D colortex3;
uniform float viewWidth;
uniform float viewHeight;

in vec4 texcoord;
in vec2 screenSunPosition;

const float offset[9] = float[] (0.0, 1.4896, 3.4757, 5.4619, 7.4482, 9.4345, 11.421, 13.4075, 15.3941);
const float weight[9] = float[] (0.066812, 0.129101, 0.112504, 0.08782, 0.061406, 0.03846, 0.021577, 0.010843, 0.004881);

vec3 blur(sampler2D image, vec2 uv, vec2 direction) {
	vec3 color = texture2D(image, uv).rgb * weight[0];
	for(int i = 1; i < 9; i++) {
		color += textureLod(image, uv + direction * offset[i], 2.0).rgb * weight[i];
		color += textureLod(image, uv - direction * offset[i], 2.0).rgb * weight[i];
	}
	return color;
}

void main() {
/* DRAWBUFFERS:1 */
/*
	vec4 clraverge = vec4(0,0,0,0);
	float range = 50;
	float count = 0;
	float x1, y1;
	vec2 cpos = screenSunPosition;
	for( float j = 1; j<=range ; j += 1 ) {
    if(cpos.x - texcoord.x==0) {
			x1 = texcoord.x;
			y1 = texcoord.y + (cpos.y - texcoord.y) * j / (6 * range);
		} else {
			float k = (cpos.y - texcoord.y) / (cpos.x - texcoord.x);
			x1 = texcoord.x + (cpos.x - texcoord.x) * j / 200;
			if((cpos.x - texcoord.x) * (cpos.x - x1) < 0)
				x1 = cpos.x;
			y1 = cpos.y - cpos.x * k + k * x1;
			if(x1 < 0.0 || y1 < 0.0 || x1 > 1.0 || y1 > 1) {
				continue;
			}
		}
		clraverge += texture2D(gcolor, vec2(x1,y1) );
		count += 1;
	}
	clraverge/=count;
	gl_FragData[0] = clraverge;
*/
	#ifdef BLOOM
		gl_FragData[0] = vec4(blur(colortex3, texcoord.st, vec2(0.0, 1.0) / vec2(viewWidth, viewHeight)), 1.0);
	#endif
}
