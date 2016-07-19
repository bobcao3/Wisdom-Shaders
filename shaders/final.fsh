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
#pragma optimize(on)

#define VIGNETTE
#define LF
#define DOF
//#define DOF_NEARVIEWBLUR
#define TILT_SHIFT

#define BLOOM
#define BLOOM_AMOUNT 0.32 // The brightness level of Bloom [0 0.25 0.32 0.41]

const bool gcolorMipmapEnabled = true;
const bool gdepthMipmapEnabled = true;

uniform sampler2D gcolor;
uniform sampler2D depthtex1;
uniform sampler2D gaux1;
uniform sampler2D colortex1;
uniform sampler2D gnormal;
uniform sampler2D shadowtex0;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float wetness;
uniform int worldTime;
uniform vec3 skyColor;

in vec4 texcoord;
flat in vec3 suncolor;

float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

#ifdef LF
	flat in float sunVisibility;
	flat in vec2 lf_pos1;
	flat in vec2 lf_pos2;
	flat in vec2 lf_pos3;
	flat in vec2 lf_pos4;
	flat in vec2 lf_pos5;

	#define MANHATTAN_DISTANCE(DELTA) abs(DELTA.x)+abs(DELTA.y)

	vec3 LENS_FLARE(vec3 COLOR, vec2 UV, vec2 LFPOS, float LFSIZE, vec4 LFCOLOR) {
		vec2 delta = UV - LFPOS;
		delta.x *= aspectRatio;
		if(MANHATTAN_DISTANCE(delta) < LFSIZE * 2.0) {
			float d = max(LFSIZE - sqrt(dot(delta, delta)), 0.0);
			return LFCOLOR.rgb * LFCOLOR.a * smoothstep(0.0, LFSIZE, d) * sunVisibility;
		}
		return vec3(0.0);
	}

	#define LF1SIZE 0.11
	#define LF2SIZE 0.15
	#define LF3SIZE 0.21
	#define LF4SIZE 0.25
	#define LF5SIZE 0.59

	const vec4 LF1COLOR = vec4(1.0, 1.0, 1.0, 0.21);
	const vec4 LF2COLOR = vec4(0.42, 0.0, 1.0, 0.12);
	const vec4 LF3COLOR = vec4(0.0, 1.0, 0.0, 0.15);
	const vec4 LF4COLOR = vec4(1.0, 0.13, 0.11, 0.19);
	const vec4 LF5COLOR = vec4(0, 0.27, 1.0, 0.11);

	vec3 lensFlare(vec3 color, vec2 uv, vec3 sun_color) {
    if(sunVisibility <= 0.0)
        return color;
		vec3 temp_color = vec3(0);
    temp_color += LENS_FLARE(color, uv, lf_pos1, LF1SIZE, LF1COLOR);
    temp_color += LENS_FLARE(color, uv, lf_pos2, LF2SIZE, LF2COLOR);
    temp_color += LENS_FLARE(color, uv, lf_pos3, LF3SIZE, LF3COLOR);
    temp_color += LENS_FLARE(color, uv, lf_pos5, LF5SIZE, LF5COLOR);
		temp_color += LENS_FLARE(color, uv, lf_pos4, LF4SIZE, LF4COLOR);
		return color + temp_color * sun_color;
	}
#endif

vec4 aux = texture2D(gaux1, texcoord.st);

float A = 0.15;
float B = 0.50;
float C = 0.10;
float D = 0.20;
float E = 0.02;
float F = 0.30;
float W = 13.134;

vec3 uncharted2Tonemap(vec3 x) {
	return ((x*(A*x+C*B)+D*E)/(x*(A*x+B)+D*F))-E/F;
}

vec3 rgbToHsl(vec3 rgbColor) {
    rgbColor = clamp(rgbColor, vec3(0.0), vec3(1.0));
    float h, s, l;
    float r = rgbColor.r, g = rgbColor.g, b = rgbColor.b;
    float minval = min(r, min(g, b));
    float maxval = max(r, max(g, b));
    float delta = maxval - minval;
    l = ( maxval + minval ) / 2.0;
    if (delta == 0.0)
    {
        h = 0.0;
        s = 0.0;
    }
    else
    {
        if ( l < 0.5 )
            s = delta / ( maxval + minval );
        else
            s = delta / ( 2.0 - maxval - minval );

        float deltaR = (((maxval - r) / 6.0) + (delta / 2.0)) / delta;
        float deltaG = (((maxval - g) / 6.0) + (delta / 2.0)) / delta;
        float deltaB = (((maxval - b) / 6.0) + (delta / 2.0)) / delta;

        if(r == maxval)
            h = deltaB - deltaG;
        else if(g == maxval)
            h = ( 1.0 / 3.0 ) + deltaR - deltaB;
        else if(b == maxval)
            h = ( 2.0 / 3.0 ) + deltaG - deltaR;

        if ( h < 0.0 )
            h += 1.0;
        if ( h > 1.0 )
            h -= 1.0;
    }
    return vec3(h, s, l);
}

float hueToRgb(float v1, float v2, float vH) {
    if (vH < 0.0)
        vH += 1.0;
    if (vH > 1.0)
        vH -= 1.0;
    if ((6.0 * vH) < 1.0)
        return (v1 + (v2 - v1) * 6.0 * vH);
    if ((2.0 * vH) < 1.0)
        return v2;
    if ((3.0 * vH) < 2.0)
        return (v1 + ( v2 - v1 ) * ( ( 2.0 / 3.0 ) - vH ) * 6.0);
    return v1;
}

vec3 hslToRgb(vec3 hslColor) {
    hslColor = clamp(hslColor, vec3(0.0), vec3(1.0));
    float r, g, b;
    float h = hslColor.r, s = hslColor.g, l = hslColor.b;
    if (s == 0.0)
    {
        r = l;
        g = l;
        b = l;
    }
    else
    {
        float v1, v2;
        if (l < 0.5)
            v2 = l * (1.0 + s);
        else
            v2 = (l + s) - (s * l);

        v1 = 2.0 * l - v2;

        r = hueToRgb(v1, v2, h + (1.0 / 3.0));
        g = hueToRgb(v1, v2, h);
        b = hueToRgb(v1, v2, h - (1.0 / 3.0));
    }
    return vec3(r, g, b);
}

vec3 vibrance(vec3 hslColor, float v) {
    hslColor.g = pow(hslColor.g, v);
    return hslColor;
}

vec3 normalDecode(vec2 enc) {
  vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
  float l = dot(nn.xyz,-nn.xyw);
  nn.z = l;
  nn.xy *= sqrt(l);
  return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

const float centerDepthHalflife = 0.5;
uniform float centerDepthSmooth;

#define DOF_FADE_RANGE 0.15
#define DOF_CLEAR_RADIUS 0.2
#define DOF_NEARVIEWBLUR

float linearizeDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

#ifdef DOF
vec3 dof(vec3 color, vec2 uv, float depth) {
    float linearFragDepth = linearizeDepth(depth);
    float linearCenterDepth = linearizeDepth(centerDepthSmooth);
    float delta = linearFragDepth - linearCenterDepth;
    #ifdef DOF_NEARVIEWBLUR
    	float fade = smoothstep(0.0, DOF_FADE_RANGE, clamp(abs(delta) - DOF_CLEAR_RADIUS, 0.0, DOF_FADE_RANGE));
    #else
    	float fade = smoothstep(0.0, DOF_FADE_RANGE, clamp(delta - DOF_CLEAR_RADIUS, 0.0, DOF_FADE_RANGE));
    #endif
		#ifdef TILT_SHIFT
			float vin_dist = distance(texcoord.st, vec2(0.5f));
			vin_dist = clamp(vin_dist * 2.1 - 0.65, 0.0, 1.0); //各种凑魔数
			vin_dist = smoothstep(0.0, 1.0, vin_dist);
			fade = max(vin_dist, fade);
		#endif
    if(fade < 0.001)
        return color;
    vec2 offset = vec2(1.33333 * aspectRatio / viewWidth, 1.33333 / viewHeight);
    vec3 blurColor = vec3(0.0);
    //0.12456 0.10381 0.12456
    //0.10380 0.08651 0.10380
    //0.12456 0.10381 0.12456
    blurColor += textureLod(gcolor, uv + offset * vec2(-1.0, -1.0), 2.0).rgb * 0.12456;
    blurColor += textureLod(gcolor, uv + offset * vec2(0.0, -1.0), 1.0).rgb * 0.10381;
    blurColor += textureLod(gcolor, uv + offset * vec2(1.0, -1.0), 2.0).rgb * 0.12456;
    blurColor += textureLod(gcolor, uv + offset * vec2(-1.0, 0.0), 1.0).rgb * 0.10381;
    blurColor += texture(gcolor, uv).rgb * 0.08651;
    blurColor += textureLod(gcolor, uv + offset * vec2(1.0, 0.0), 1.0).rgb * 0.10381;
    blurColor += textureLod(gcolor, uv + offset * vec2(-1.0, 1.0), 2.0).rgb * 0.12456;
    blurColor += textureLod(gcolor, uv + offset * vec2(0.0, 1.0), 1.0).rgb * 0.10381;
    blurColor += textureLod(gcolor, uv + offset * vec2(1.0, 1.0), 2.0).rgb * 0.12456;
    return mix(color, blurColor, fade);
}
#endif

void main() {

	vec3 color =  texture(gcolor, texcoord.st).rgb;

	float depth = texture(depthtex1, texcoord.st).x;

	#ifdef DOF
		color = dof(color, texcoord.st, depth);
	#endif

	#ifdef BLOOM
	vec3 highlight = textureLod(colortex1, texcoord.st, 1.0).rgb;
	color = pow(color, vec3(1.4));
	color *= 6.0;
	vec3 curr = uncharted2Tonemap(color);
	vec3 whiteScale = 1.0f/uncharted2Tonemap(vec3(W));
	color = curr*whiteScale;

	color += highlight * BLOOM_AMOUNT;

	#endif

	vec3 hslColor = rgbToHsl(color);
	hslColor = vibrance(hslColor, 0.85);
	color = hslToRgb(hslColor);

	#ifdef LF
		color = lensFlare(color, texcoord.st, suncolor * (1 - wetness * 0.86) * 0.42);
	#endif

	#ifdef VIGNETTE
		float vin_dist = distance(texcoord.st, vec2(0.5f));
  	vin_dist = clamp(vin_dist * 1.7 - 0.65, 0.0, 1.0); //各种凑魔数
  	vin_dist = smoothstep(0.0, 1.0, vin_dist);
  	color.rgb *= (1.0 - vin_dist);
	#endif

	gl_FragColor = vec4(color, 1.0);
}
