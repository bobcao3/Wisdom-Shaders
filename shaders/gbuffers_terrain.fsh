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
#extension GL_ARB_shader_texture_lod : enable
#pragma optimize(on)

#define NORMAL_MAPPING

const int noiseTextureResolution = 256;

uniform int fogMode;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D specular;
uniform sampler2D normals;

in vec4 color;
in vec4 texcoord;
in vec4 lmcoord;
flat in vec3 normal;
flat in vec3 binormal;
flat in vec3 tangent;
flat in float entities;
flat in float iswater;

vec2 normalEncode(vec3 n) {
    vec2 enc = normalize(n.xy) * (sqrt(-n.z*0.5+0.5));
    enc = enc*0.5+0.5;
    return enc;
}

vec2 dcdx = dFdx(texcoord.st);
vec2 dcdy = dFdy(texcoord.st);

/* DRAWBUFFERS:0246 */
void main() {
	vec4 texcolor = textureProjGrad(texture, texcoord, dcdx, dcdy);
  vec4 normal_map = textureProjGrad(normals, texcoord, dcdx, dcdy);
	vec3 normal_r;
  #ifdef NORMAL_MAPPING
    if (length(normal_map.rgb) > 0) {
      vec3 bump = normal_map.rgb * 2.0 - 1.0;
      bump = bump * vec3(0.5) + vec3(0.0, 0.0, 0.5);
      mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
          tangent.y, binormal.y, normal.y,
          tangent.z, binormal.z, normal.z);

		  normal_r = normalize(bump * tbnMatrix);
      normal_r = gl_NormalMatrix * normalize(normal_r);
	  } else {
      normal_r = gl_NormalMatrix * normal;
    }
  #else
    normal_r = gl_NormalMatrix * normal;
  #endif

	gl_FragData[0] = texcolor * color;
	gl_FragData[1] = vec4(normalEncode(normal_r), 0.0, 1.0);
	gl_FragData[2] = vec4(lmcoord.t, entities, lmcoord.s, 1.0);
	gl_FragData[3] = vec4(textureProjGrad(specular, texcoord, dcdx, dcdy).rgb, texcolor.a);
}
