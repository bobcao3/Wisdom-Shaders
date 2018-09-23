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
#else
varying vec2 n2;
#endif

varying f16vec4 color;
varying vec4 coords;
varying vec4 wdata;

varying float dis;

#define normal wdata.xyz
#define flag wdata.w

#define texcoord coords.rg
#define lmcoord coords.ba

#ifdef NORMALS
varying f16vec3 tangent;
varying f16vec3 binormal;

f16vec2 normalEncode(f16vec3 n) {
	return sqrt(-n.z*0.125f+0.125f) * normalize(n.xy) + 0.5f;
}
#endif

#define DIRECTIONAL_LIGHTMAP

uniform ivec2 atlasSize;

#define ParallaxOcclusion
#ifdef ParallaxOcclusion
varying f16vec3 tangentpos;

#define TILE_RESOLUTION 0 // [32 64 128 256 512 1024]

vec2 atlas_offset(in vec2 coord, in vec2 offset) {
	const ivec2 atlasTiles = ivec2(32, 16);
	#if TILE_RESOLUTION == 0
	int tileResolution = atlasSize.x / atlasTiles.x * 2;
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
	#define scale 0.01 // [0.005 0.01 0.02]

	float heightmap = texture2D(normals, coord.st).a - 1.0f;

	vec3 offset = vec3(0.0f, 0.0f, 0.0f);
	vec3 s = tangentpos;//normalize(tangentpos);
	s = s / s.z * scale / maxSteps;

	float lazyx = 0.5;
	const float lazyinc = 0.25 / maxSteps;

	if (heightmap < 0.0f) {
		for (int i = 0; i < maxSteps; i++) {
			float prev = offset.z;
			
			offset += (heightmap - prev) * lazyx * s;
			lazyx += lazyinc;
			
			adjusted = atlas_offset(coord.st, offset.st);
			heightmap = texture2D(normals, adjusted).a - 1.0f;
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
			
			heightmap = texture2D(normals, atlas_offset(coord.st, light_offset.st)).a - 1.0f;
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

float rand(float n){return fract(sin(n) * 43758.5453123);}

float noise(float p){
	float fl = floor(p);
	float fc = fract(p);
	return mix(rand(fl), rand(fl + 1.0), fc);
}

#if defined(DIRECTIONAL_LIGHTMAP) && defined(NORMALS)
float lightmap_normals(vec3 N, float l) {
	if (l < 0.0001 || l > 0.98) {
		return 1.0;
	}

	float dither = noise(dis) * 0.1;

	float Lx = dFdx(l) * 120.0 + dither;
	float Ly = dFdy(l) * 120.0 + dither;

	vec3 TL = normalize(vec3(Lx * tangent + 0.0005 * normal + Ly * binormal));

	return clamp(dot(N, TL) * 0.2 + 0.8, 0.0, 1.0);
}
#endif

//#define SPECULAR_TO_PBR_CONVERSION
//#define CONTINUUM2_TEXTURE_FORMAT

/* DRAWBUFFERS:0245 */
void main() {
	vec2 texcoord_adj = texcoord;
	#ifdef ParallaxOcclusion
	if (dis < 64.0) texcoord_adj = ParallaxMapping(texcoord);
	#endif

	f16vec4 t = texture2D(texture, texcoord_adj);

	#ifdef PARALLAX_SELF_SHADOW
	t.rgb *= parallax_lit;
	#endif

	gl_FragData[0] = t * color;
	vec2 lm;
	#ifdef NORMALS
		f16vec2 n2 = normalEncode(normal);
		f16vec3 normal2 = normal;
		if (dis < 64.0) {
			normal2 = texture2D(normals, texcoord_adj).xyz * 2.0 - 1.0;
			const float16_t bumpmult = 0.5;
			normal2 = normal2 * bumpmult + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			f16mat3 tbnMatrix = mat3(tangent, binormal, normal);
			normal2 = tbnMatrix * normal2;
		}

		#ifdef DIRECTIONAL_LIGHTMAP
		lm = lmcoord * vec2(lightmap_normals(normal2, lmcoord.x), lightmap_normals(normal2, lmcoord.y));
		#endif

		vec2 d = normalEncode(normal2);
		if (!(d.x > 0.0 && d.y > 0.0)) d = n2;
		gl_FragData[1] = vec4(d, flag, 1.0);
	#else
		gl_FragData[1] = vec4(n2, flag, 1.0);
	#endif
	#ifdef SPECULAR_TO_PBR_CONVERSION
	vec3 spec = texture2D(specular, texcoord_adj).rgb;
	float spec_strength = dot(spec, vec3(0.3, 0.6, 0.1));
	gl_FragData[2] = vec4(spec_strength, spec_strength, 0.0, 0.0);
	#else
	#ifdef CONTINUUM2_TEXTURE_FORMAT
	gl_FragData[2] = texture2D(specular, texcoord_adj).brga;
	#else
	gl_FragData[2] = texture2D(specular, texcoord_adj);
	#endif
	#endif

	#if defined(DIRECTIONAL_LIGHTMAP) && defined(NORMALS)
	gl_FragData[3] = vec4(lm, n2);
	#else
	gl_FragData[3] = vec4(lmcoord, n2);
	#endif
}
