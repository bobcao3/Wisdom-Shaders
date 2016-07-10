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

uniform float rainStrength;
uniform float frameTimeCounter;
uniform sampler2D noisetex;

attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

out vec4 color;
out vec4 texcoord;
out vec4 lmcoord;
out vec3 normal;
out vec3 binormal;
out vec3 tangent;
out float entities;
out float iswater;

void main()
{
	vec4 position = gl_Vertex;
	float blockId = mc_Entity.x;
  iswater = 0.0;
	entities = 0.22;
  if (blockId == 8.0 || blockId == 9.0) {
    iswater = 1.0;
  } else {
	  if((blockId == 31.0 || blockId == 37.0 || blockId == 38.0) && gl_MultiTexCoord0.t < mc_midTexCoord.t) {
		  float blockId = mc_Entity.x;
		  vec3 noise = texture2D(noisetex, position.xz / 256.0).rgb;
		  float maxStrength = 1.0 + rainStrength * 0.5;
		  float time = frameTimeCounter * 3.0;
		  float reset = cos(noise.z * 10.0 + time * 0.1);
  		reset = max( reset * reset, max(rainStrength, 0.1));
  		position.x += sin(noise.x * 10.0 + time) * 0.2 * reset * maxStrength;
  		position.z += sin(noise.y * 10.0 + time) * 0.2 * reset * maxStrength;

      entities = 0.4;
    }	else if(blockId == 18.0 || blockId == 106.0 || blockId == 161.0 || blockId == 175.0) {
		  vec3 noise = texture2D(noisetex, (position.xz + 0.5) / 16.0).rgb;
		  float maxStrength = 1.0 + rainStrength * 0.5;
	    float time = frameTimeCounter * 3.0;
  		float reset = cos(noise.z * 10.0 + time * 0.1);
  		reset = max( reset * reset, max(rainStrength, 0.1));
  		position.x += sin(noise.x * 10.0 + time) * 0.07 * reset * maxStrength;
  		position.z += sin(noise.y * 10.0 + time) * 0.07 * reset * maxStrength;

      entities = 0.4;
    } else if (blockId == 83.0 || blockId == 39 || blockId ==40 || blockId == 6.0 || blockId == 104 || blockId == 105 || blockId == 115 || blockId == 141 || blockId == 142) {
      entities = 0.4;
	  }
	}

	normal = gl_Normal;
	if (gl_Normal.x > 0.5) {
		//  1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0, -1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.x < -0.5) {
		// -1.0,  0.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.y > 0.5) {
		//  0.0,  1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.y < -0.5) {
		//  0.0, -1.0,  0.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0,  0.0,  1.0));
	} else if (gl_Normal.z > 0.5) {
		//  0.0,  0.0,  1.0
		tangent  = normalize(gl_NormalMatrix * vec3( 1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	} else if (gl_Normal.z < -0.5) {
		//  0.0,  0.0, -1.0
		tangent  = normalize(gl_NormalMatrix * vec3(-1.0,  0.0,  0.0));
		binormal = normalize(gl_NormalMatrix * vec3( 0.0, -1.0,  0.0));
	}

	position = gl_ModelViewMatrix * position;
	gl_Position = gl_ProjectionMatrix * position;
	gl_FogFragCoord = length(position.xyz);
	color = gl_Color;
	texcoord = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	lmcoord = gl_TextureMatrix[1] * gl_MultiTexCoord1;
}
