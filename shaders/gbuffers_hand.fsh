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

#pragma optimize(on)

//#define SMOOTH_TEXTURE

#define NORMALS

uniform sampler2D texture;
uniform sampler2D specular;
#ifdef NORMALS
uniform sampler2D normals;
#endif

varying vec4 color;
varying vec4 coords;
varying vec3 normal;

#define texcoord coords.rg
#define lmcoord coords.ba

#ifdef NORMALS
varying vec3 tangent;
varying vec3 binormal;
#endif

vec2 normalEncode(vec3 n) {return sqrt(-n.z*0.125+0.125) * normalize(n.xy) + 0.5;}

//#define SPECULAR_TO_PBR_CONVERSION
//#define CONTINUUM2_TEXTURE_FORMAT

/* DRAWBUFFERS:0245 */
void main() {
	vec4 t = texture2D(texture, texcoord);

	gl_FragData[0] = t * color;
	vec2 n2 = normalEncode(normal);
	#ifdef NORMALS
		vec3 normal2 = texture2D(normals, texcoord).xyz * 2.0 - 1.0;
		const float bumpmult = 0.5;
		normal2 = normal2 * bumpmult + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		mat3 tbnMatrix = mat3(
			tangent.x, binormal.x, normal.x,
			tangent.y, binormal.y, normal.y,
			tangent.z, binormal.z, normal.z);
		normal2 = normal2 * tbnMatrix;
		vec2 d = normalEncode(normal2);
		if (!(d.x > 0.0 && d.y > 0.0)) d = n2;
		gl_FragData[1] = vec4(d, 0.3, 1.0);
	#else
		gl_FragData[1] = vec4(n2, 0.3, 1.0);
	#endif
	#ifdef SPECULAR_TO_PBR_CONVERSION
	vec3 spec = texture2D(specular, texcoord).rgb;
	float spec_strength = dot(spec, vec3(0.3, 0.6, 0.1));
	gl_FragData[2] = vec4(spec_strength, spec_strength, 0.0, 1.0);
	#else
	#ifdef CONTINUUM2_TEXTURE_FORMAT
	gl_FragData[2] = vec4(texture2D(specular, texcoord).brg, 1.0);
	#else
	gl_FragData[2] = vec4(texture2D(specular, texcoord).rgb, 1.0);
	#endif
	#endif
	gl_FragData[3] = vec4(lmcoord, n2);
}
