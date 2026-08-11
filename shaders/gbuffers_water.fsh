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

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

varying vec2 normal;
varying vec4 coords;
varying vec3 viewNormal;
varying vec3 tangent;
varying vec3 bitangent;
varying float blockLight;

#define texcoord coords.rg
#define skyLight coords.b
#define iswater coords.a

vec2 normalEncode(vec3 n) {
	return n.xy * inversesqrt(n.z * 8.0 + 8.0) + 0.5;
}

/* DRAWBUFFERS:7189 */
void main() {
	vec4 color = vec4(0.0);
	vec2 encodedNormal = normal;
	vec4 specularData;
#ifdef SPECULAR_TO_PBR_CONVERSION
	float specularStrength = dot(texture2D(specular, texcoord).rgb, vec3(0.3, 0.6, 0.1));
	specularData = vec4(specularStrength, specularStrength, 0.0, 0.0);
#elif defined CONTINUUM2_TEXTURE_FORMAT
	specularData = texture2D(specular, texcoord).brga;
#else
	vec4 labPBRData = texture2D(specular, texcoord);
	specularData = vec4(labPBRData.r, labPBRData.g, labPBRData.a, labPBRData.a);
#endif
	if (iswater > 0.78f && iswater < 0.8f)
		color = vec4(vec3(0.0537,0.3562,0.5097) * skyLight * 0.2, 1.0);
	else {
		color = texture2D(tex, texcoord);
		vec3 normal2 = texture2D(normals, texcoord).xyz * 2.0 - 1.0;
		normal2 = normal2 * 0.5 + vec3(0.0, 0.0, 0.5);
		normal2 = normalize(mat3(tangent, bitangent, viewNormal) * normal2);
		encodedNormal = normalEncode(normal2);
	}
	
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(encodedNormal, iswater, skyLight);
	gl_FragData[2] = specularData;
	gl_FragData[3] = vec4(blockLight, 0.0, 0.0, 1.0);
}
