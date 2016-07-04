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

#define LF

#ifdef LF

	#define LF1POS -0.3
	#define LF2POS 0.2
	#define LF3POS 0.7
	#define LF4POS 0.75
	#define LF5POS 0.77

	uniform float viewWidth;
	uniform float viewHeight;
	uniform vec3 sunPosition;
	uniform mat4 gbufferProjection;
	uniform sampler2D depthtex0;

	out float sunVisibility;
	out vec2 lf_pos1;
	out vec2 lf_pos2;
	out vec2 lf_pos3;
	out vec2 lf_pos4;
	out vec2 lf_pos5;

#endif

out vec4 texcoord;


void main() {
	#ifdef LF
		vec4 ndcSunPosition = gbufferProjection * vec4(normalize(sunPosition), 1.0);
		ndcSunPosition /= ndcSunPosition.w;
		vec2 pixelSize = vec2(1.0 / viewWidth, 1.0 / viewHeight);
		sunVisibility = 0.0f;
		vec2 screenSunPosition = vec2(-10.0);
		lf_pos1 = lf_pos2 = lf_pos3 = lf_pos4 = vec2(-10.0);
		if(ndcSunPosition.x >= -1.0 && ndcSunPosition.x <= 1.0 && ndcSunPosition.y >= -1.0 && ndcSunPosition.y <= 1.0 && ndcSunPosition.z >= -1.0 && ndcSunPosition.z <= 1.0) {

			screenSunPosition = ndcSunPosition.xy * 0.5 + 0.5;
			for(int x = -4; x <= 4; x++) {
				for(int y = -4; y <= 4; y++) {
						float depth = texture2DLod(depthtex0, screenSunPosition.st + vec2(float(x), float(y)) * pixelSize, 0.0).r;
					if(depth > 0.9999)
						sunVisibility += 1.0 / 81.0;
				}
			}
			float shortestDis = min( min(screenSunPosition.s, 1.0 - screenSunPosition.s), min(screenSunPosition.t, 1.0 - screenSunPosition.t));
			sunVisibility *= smoothstep(0.0, 0.2, clamp(shortestDis, 0.0, 0.2));

			vec2 dir = vec2(0.5) - screenSunPosition;
			lf_pos1 = vec2(0.5) + dir * LF1POS;
			lf_pos2 = vec2(0.5) + dir * LF2POS;
			lf_pos3 = vec2(0.5) + dir * LF3POS;
			lf_pos4 = vec2(0.5) + dir * LF4POS;
			lf_pos5 = vec2(0.5) + dir * LF5POS;
		}
	#endif

	gl_Position = ftransform();
	texcoord = gl_MultiTexCoord0;
}
