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
varying vec4 wdata;

varying float dis;

#define normal wdata.xyz
#define flag wdata.w

#define texcoord coords.rg
#define lmcoord coords.ba

#ifdef NORMALS
varying vec3 tangent;
varying vec3 binormal;
#endif

varying vec4 texcoordb;

vec2 dcdx = dFdx(texcoordb.st * texcoordb.pq);
vec2 dcdy = dFdy(texcoordb.st * texcoordb.pq);

uniform ivec2 atlasSize;

#define texF(a,b) texture2DGradARB(a, b, dcdx, dcdy)

//#define ParallaxOcculusion
#ifdef ParallaxOcculusion
varying vec3 tangentpos;

#define TILE_RESOLUTION 0 // [32 64 128 256 512 1024]

vec2 atlas_offset(in vec2 coord, in vec2 offset) {
	const ivec2 atlasTiles = ivec2(16, 8);
	#if TILE_RESOLUTION == 0
	int tileResolution = atlasSize.x / atlasTiles.x;
	#else
	int tileResolution = TILE_RESOLUTION;
	#endif

	coord *= atlasSize;

	vec2 offsetCoord = coord + mod(offset.xy * atlasSize, vec2(tileResolution));

	vec2 minCoord = vec2(coord.x - mod(coord.x, tileResolution), coord.y - mod(coord.y, tileResolution));
	vec2 maxCoord = minCoord + tileResolution;

	if (offsetCoord.x > maxCoord.x)
		offsetCoord.x -= tileResolution;
	else if (offsetCoord.x < minCoord.x)
		offsetCoord.x += tileResolution;

	if (offsetCoord.y > maxCoord.y)
		offsetCoord.y -= tileResolution;
	else if (offsetCoord.y < minCoord.y)
		offsetCoord.y += tileResolution;

	offsetCoord /= atlasSize;

	return offsetCoord;
}

//#define PARALLAX_SELF_SHADOW
#ifdef PARALLAX_SELF_SHADOW
varying vec3 sun;
float parallax_lit = 1.0;
#endif

vec2 ParallaxMapping(in vec2 coord) {
	vec2 adjusted = coord.st;
	#define maxSteps 8 // [4 8 16]
	#define scale 0.03 // [0.01 0.03 0.05]

	float heightmap = texF(normals, coord.st).a - 1.0f;

	vec3 offset = vec3(0.0f, 0.0f, 0.0f);
	vec3 s = normalize(tangentpos);
	s = s / s.z * scale / maxSteps;

	float lazyx = 0.5;
	const float lazyinc = 0.25 / maxSteps;

	if (heightmap < 0.0f) {
		for (int i = 0; i < maxSteps; i++) {
			float prev = offset.z;
			
			offset += (heightmap - prev) * lazyx * s;
			lazyx += lazyinc;
			
			adjusted = atlas_offset(coord.st, offset.st);
			heightmap = texF(normals, adjusted).a - 1.0f;
			if (max(0.0, offset.z - heightmap) < 0.05) break;
		}
		
		#ifdef PARALLAX_SELF_SHADOW
		s = normalize(sun);
		s = s * scale * 10.0 / maxSteps;
		vec3 light_offset = offset;
		
		for (int i = 0; i < maxSteps; i++) {
			float prev = offset.z;
			
			light_offset += s;
			lazyx += lazyinc;
			
			heightmap = texF(normals, atlas_offset(coord.st, light_offset.st)).a - 1.0f;
			if (heightmap > light_offset.z) {
				parallax_lit = 0.5;
				break;
			}
		}
		#endif
	}

	return adjusted;
}
#endif

vec2 normalEncode(vec3 n) {return sqrt(-n.z*0.125+0.125) * normalize(n.xy) + 0.5;}

/* DRAWBUFFERS:0245 */
void main() {
	vec2 texcoord_adj = texcoord;
	#ifdef ParallaxOcculusion
	if (dis < 64.0) texcoord_adj = ParallaxMapping(texcoord);
	#endif

	vec4 t = texF(texture, texcoord_adj);

	if (t.a <= 0.0) discard;

	#ifdef PARALLAX_SELF_SHADOW
	t.rgb *= parallax_lit;
	#endif

	gl_FragData[0] = t * color;
	vec2 n2 = normalEncode(normal);
	#ifdef NORMALS
		vec3 normal2 = normal;
		if (dis < 64.0) {
			normal2 = texF(normals, texcoord_adj).xyz * 2.0 - 1.0;
			const float bumpmult = 0.5;
			normal2 = normal2 * vec3(bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			mat3 tbnMatrix = mat3(
				tangent.x, binormal.x, normal.x,
				tangent.y, binormal.y, normal.y,
				tangent.z, binormal.z, normal.z);
			normal2 = normal2 * tbnMatrix;
		}
		gl_FragData[1] = vec4(normalEncode(normal2), flag, 1.0);
	#else
		gl_FragData[1] = vec4(n2, flag, 1.0);
	#endif
	gl_FragData[2] = texF(specular, texcoord_adj);
	gl_FragData[3] = vec4(lmcoord, n2);
}
