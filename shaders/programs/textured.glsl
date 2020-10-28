#include "/libs/compat.glsl"
#include "/libs/encoding.glsl"

#include "/libs/color.glsl"

inout vec4 color;
inout flat vec3 normal;
inout flat float subsurface;
inout flat float blockId;

#ifdef NORMAL_MAPPING
inout flat vec3 tangent;
inout flat vec3 bitangent;
#endif

#ifdef POM
inout vec3 tangentpos;
#endif

#if (!defined(ENTITY) && defined(RAIN_PUDDLES) || defined(POM))
inout vec3 worldPos;
inout vec3 viewPos;
#else
vec3 worldPos;
vec3 viewPos;
#endif

inout vec2 uv;
inout vec2 lmcoord;

uniform vec3 cameraPosition;

uniform int frameCounter;

#include "/libs/taa.glsl"

#ifdef VERTEX

uniform vec2 invWidthHeight;

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

#ifdef ENTITY
uniform vec4 entityColor;
#endif

#define WAVING_FOILAGE

uniform mat4 gbufferModelViewInverse;

uniform float rainStrength;
uniform float frameTimeCounter;

attribute vec4 mc_midTexCoord;

#include "/libs/noise.glsl"

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
#ifdef ENTITY
    color += entityColor;
#endif
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    normal = normalize(gl_NormalMatrix * gl_Normal);

#ifdef NORMAL_MAPPING
    tangent = normalize(gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
    bitangent = cross(tangent, normal);
#endif

#if defined(WAVING_FOILAGE) && !defined(ENTITY)
    float maxStrength = 0.5 + rainStrength;
    float time = frameTimeCounter * 3.0;

	if (mc_Entity.x == 31.0) {
		if (gl_MultiTexCoord0.t < mc_midTexCoord.t) {
			float rand_ang = hash(input_pos.xz);
			float reset = cos(rand_ang * 10.0 + time * 0.1);
			reset = max( reset * reset, max(rainStrength * 0.5, 0.1));
			input_pos.x += (sin(rand_ang * 10.0 + time + input_pos.y) * 0.2) * (reset * maxStrength);
		}
	} else if (mc_Entity.x == 18.0) {
		float rand_ang = hash(input_pos.xz);
		float reset = cos(rand_ang * 10.0 + time * 0.1);
		reset = max( reset * reset, max(rainStrength * 0.5, 0.1));
		input_pos.x += (sin(rand_ang * 5.0 + time + input_pos.x) * 0.035 + 0.035) * (reset * maxStrength);
		input_pos.y += (cos(rand_ang * 5.0 + time + input_pos.y) * 0.01 + 0.01) * (reset * maxStrength);
		input_pos.z += (sin(rand_ang * 5.0 + time + input_pos.z) * 0.035 + 0.035) * (reset * maxStrength);
    }
#endif

    subsurface = 0.0;

    blockId = mc_Entity.x;
    if (blockId == 31.0) {
        subsurface = 0.3;        
    } else if (blockId == 18.0) {
        subsurface = 0.5;
    } else if (blockId == 79.0) {
        subsurface = 0.3;
    } else if (blockId == 8001.0) {
        subsurface = 0.5;
    }

    subsurface /= 16.0;

    vec4 vpos = model_view_mat * input_pos;
    viewPos = vpos.xyz;
    worldPos = (gbufferModelViewInverse * vpos).xyz;

    gl_Position = proj_mat * vpos;

#ifdef POM
	mat3 TBN = mat3(tangent, bitangent, normal);
	tangentpos = normalize(viewPos * TBN);
#endif

#ifndef NO_TAA
    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
#endif
}

#else

uniform sampler2D tex;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D gaux3;

uniform float near;
uniform float far;
uniform mat4 gbufferProjection;

uniform float wetness;

#include "/libs/noise.glsl"

#define RAIN_PUDDLES

#ifdef NORMAL_MAPPING
float getDirectional(float lm, vec3 normal2) {
	float Lx = dFdx(lm) * 60.0;
	float Ly = dFdy(lm) * 60.0;

	vec3 TL = normalize(vec3(Lx * tangent + 0.005 * normal + Ly * bitangent));
	float dir_lighting = fma((dot(normal2, TL)), 0.33, 0.67);
	
	return clamp(dir_lighting * 1.4, 0.0, 1.0);
}
#endif

#ifdef POM
#define tileResolution 128 // [16 32 64 128 256 512 1024]

uniform ivec2 atlasSize;

vec2 tileResolutionF = vec2(tileResolution) / atlasSize;

vec2 minCoord = vec2(uv.x - mod(uv.x, tileResolutionF.x), uv.y - mod(uv.y, tileResolutionF.y));
vec2 maxCoord = minCoord + tileResolutionF;

vec2 atlas_offset(in vec2 coord, in vec2 offset) {
	vec2 offsetCoord = coord + mod(offset.xy, tileResolutionF);

	offsetCoord.x -= float(offsetCoord.x > maxCoord.x) * tileResolutionF.x;
	offsetCoord.x += float(offsetCoord.x < minCoord.x) * tileResolutionF.x;

	offsetCoord.y -= float(offsetCoord.y > maxCoord.y) * tileResolutionF.y;
	offsetCoord.y += float(offsetCoord.y < minCoord.y) * tileResolutionF.y;

	return offsetCoord;
}

ivec2 atlas_offset(in ivec2 coord, in ivec2 offset, int lodi) {
    int tileResLod = (tileResolution >> lodi);

	ivec2 offsetCoord = coord + offset.xy % tileResLod;

    ivec2 minCoordi = coord - coord % tileResLod;
    ivec2 maxCoordi = minCoordi + tileResLod;

	offsetCoord.x -= int(offsetCoord.x >= maxCoordi.x) * tileResLod;
	offsetCoord.x += int(offsetCoord.x < minCoordi.x) * tileResLod;

	offsetCoord.y -= int(offsetCoord.y >= maxCoordi.y) * tileResLod;
	offsetCoord.y += int(offsetCoord.y < minCoordi.y) * tileResLod;

	return offsetCoord;
}

vec2 ParallaxMapping(in vec2 coord) {
	vec2 adjusted = coord.st;
	#define POM_STEPS 4 // [4 8 16]
	#define scale 0.01 // [0.005 0.01 0.02 0.04]

	float heightmap = texture(normals, coord.st).a - 1.0f;

	vec3 offset = vec3(0.0f, 0.0f, 0.0f);
	vec3 s = normalize(tangentpos);
	s = s / s.z * scale / POM_STEPS;

	float lazyx = 0.5;
	const float lazyinc = 0.5 / POM_STEPS;

	if (heightmap < 0.0f) {
		for (int i = 0; i < POM_STEPS; i++) {
			float prev = offset.z;

			offset += (heightmap - prev) * lazyx * s;
			lazyx += lazyinc;

			adjusted = atlas_offset(coord.st, offset.st);
			heightmap = texture(normals, adjusted).a - 1.0f;
			if (max(0.0, offset.z - heightmap) < 0.05) break;
		}
	}

	return adjusted;
}
#endif

void fragment() {
/* DRAWBUFFERS:4 */
    float threshold = fract(texelFetch(gaux3, ivec2(gl_FragCoord.st) % 0xFF, 0).r + texelFetch(gaux3, ivec2(frameCounter, int(gl_FragCoord.z * 655336.0)) % 0xFF, 0).r) * 0.95 + 0.05;

    vec2 ddx = dFdx(uv);
    vec2 ddy = dFdy(uv);

    float dL = min(length(ddx), length(ddy.x));
    float lod = clamp(round(log2(dL * textureSize(tex, 0).x) - 1.0), 0, 3);

#ifdef POM
    vec2 adjuv = ParallaxMapping(uv);
#else
    #define adjuv uv
#endif

    vec2 lmcoord_dithered = lmcoord + bayer8(gl_FragCoord.st) * 0.004;

#if (defined(ENTITY) || !defined(NORMAL_MAPPING))
    vec3 normal_map = normal;
#else
    vec3 normal_map;
    normal_map.xy = texture(normals, adjuv).rg * 2.0 - 1.0;
    normal_map.z = sqrt(1.0 - dot(normal_map.xy, normal_map.xy));
    normal_map = mat3(tangent, bitangent, normal) * normal_map;
#endif

#ifdef NORMAL_MAPPING
    // lmcoord_dithered.x *= getDirectional(lmcoord.x, normal_map);
#endif

    vec4 specular_map = textureLod(specular, adjuv, floor(lod));

    if (blockId > 8001.5 && blockId < 8002.5) {
        specular_map.a = 0.95;
    }

    #ifdef UNLIT
    lmcoord_dithered = vec2(0.7);
    specular_map.a = 0.95;
    #endif

#if defined(SMOOTH_TEXTURE) && defined(POM)
#ifdef SMOOTH_TEXTURE
    ivec2 texSize = textureSize(tex, int(floor(lod)));
    vec2 iuv = vec2(texSize) * adjuv;
    vec2 fuv = floor(iuv);

    int lodi = int(floor(lod));

    vec4 c00 = texelFetch(tex, atlas_offset(ivec2(fuv), ivec2(0, 0), lodi), lodi);
    vec4 c01 = texelFetch(tex, atlas_offset(ivec2(fuv), ivec2(0, 1), lodi), lodi);
    vec4 c10 = texelFetch(tex, atlas_offset(ivec2(fuv), ivec2(1, 0), lodi), lodi);
    vec4 c11 = texelFetch(tex, atlas_offset(ivec2(fuv), ivec2(1, 1), lodi), lodi);

    vec4 c = color * mix(
        mix(c00, c01, iuv.y - fuv.y),
        mix(c10, c11, iuv.y - fuv.y), iuv.x - fuv.x
    );
#endif
#else
    vec4 c = color * textureLod(tex, adjuv, lod);
#endif

    c.rgb += vec3(threshold - 0.5) / vec3(32.0, 64.0, 32.0);
    c.rgb = max(c.rgb, vec3(0.0));

#if (!defined(ENTITY) && defined(RAIN_PUDDLES))
    float wetnessMorph = 0.5 * noise(worldPos.xz + cameraPosition.xz);
    wetnessMorph += 1.5 * noise(worldPos.xz * 0.5 + cameraPosition.xz * 0.5);
    wetnessMorph += 2.0 * noise(worldPos.xz * 0.2 + cameraPosition.xz * 0.2);
    wetnessMorph = clamp(wetnessMorph + 1.0, 0.0, 1.0) * wetness * smoothstep(0.9, 0.95, lmcoord.y);

    if (threshold < wetnessMorph * pow3(1.0 - abs(dot(normalize(viewPos), normal))))
    {
        specular_map.rg = vec2(0.99, 1.0);
        normal_map = normal;
    }

#ifdef RAIN_PUDDLES
    if (specular_map.b < 0.25) c.rgb *= 1.0 - specular_map.b * 2.0;
#endif
#endif

    if (c.a < threshold) discard;
    fragData[0] = uvec3(normalEncode(normal_map), encodeAlbedoSpecular(c.rgb, specular_map.rg), packUnorm4x8(vec4(lmcoord_dithered, subsurface, specular_map.a)));
}

#endif