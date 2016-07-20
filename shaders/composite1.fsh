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

#define PI 3.14159

#define TEST_CLOUD
//#define HQ_SMOOTH_SHADOW
#define BLOOM
#define DRSOE_SS
#define SSADDAO

#define SHADOW_MAP_BIAS 0.85
const int     RG16 = 0;
const int     RGBA8 = 0;
const int     colortex1Format = RGBA8;
const int     gnormalFormat = RG16;
const int     gaux1Format = RGBA8;

#ifdef DRSOE_SS
const int     shadowMapResolution     = 2048;
#else
#ifdef HQ_SMOOTH_SHADOW
const int     shadowMapResolution     = 2048;
#else
const int     shadowMapResolution     = 1024;
#endif
#endif
const float   shadowDistance          = 128.0f;
const float 	centerDepthHalflife 	  = 2.0f;
const float 	shadowIntervalSize 		  = 6.0f;
const float 	wetnessHalflife 		 	  = 450.0f; 	 // Wet to dry.
const float 	drynessHalflife 		 	  = 60.0f;		 // Dry ro wet.
const float		sunPathRotation			 	  = -39.5f;
const float		eyeBrightnessHalflife	  = 8.5f;
#ifdef DRSOE_SS
const bool    shadowtex1Mipmap        = true;
const bool    shadowcolor0Mipmap      = true;
#else
#ifdef HQ_SMOOTH_SHADOW
const bool    shadowtex1Mipmap        = true;
const bool    shadowcolor0Mipmap      = true;
#endif
#endif
const bool    gcolorMipmapEnabled     = true;
#ifdef SSADDAO
const bool    depthtex1MipmapEnabled  = true;
const float   ambientOcclusionLevel   = 0.0f;
#else
const float   ambientOcclusionLevel   = 1.0f;
#endif

uniform float far;
uniform float near;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform vec3 cameraPosition;
uniform bool isEyeInWater;
uniform int worldTime;
uniform int fogMode;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;
uniform sampler2D gcolor;
uniform sampler2D gnormal;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D shadowtex0;
#ifdef DRSOE_SS
uniform sampler2D shadowtex1;
#else
uniform sampler2DShadow shadowtex1;
#endif
uniform sampler2D shadowcolor0;

flat in float extShadow;
flat in vec3 lightPosition;
in vec3 upVec;
in vec3 sunVec;
in vec3 moonVec;
flat in vec3 suncolor;
in float SdotU;
in float MdotU;
flat in vec3 skyColorC;
vec3 skyColor = skyColorC;
flat in float moonVisibility;
in vec4 texcoord;
flat in float handlight;
flat in vec3 worldSunPosition;

flat in float TimeSunrise;
flat in float TimeNoon;
flat in float TimeSunset;
flat in float TimeMidnight;

struct SurfaceStruct {
  vec4 worldPosition;
  lowp vec3 normal;
  vec4 viewPosition;

  float dist;
} surface, surface_nw;

vec4 color;

vec3 normalDecode(vec2 enc) {
  vec4 nn = vec4(2.0f * enc - 1.0f, 1.0f, -1.0f);
  float l = dot(nn.xyz, -nn.xyw);
  nn.z = l;
  nn.xy *= sqrt(l);
  return nn.xyz * 2.0f + vec3(0.0f, 0.0f, -1.0f);
}

struct SurfaceMask {
  vec4 aux;
  float blockId;

  bool iswater;
  bool issky;
  bool issun;
  bool ishand;
  bool is_stained_glass;
} mask;

#ifdef DRSOE_SS
  const float shadow_weight[5] = float[] (1.0, 0.71, 0.57, 0.33, 0.12);
  const vec2 shadow_disp[5] = vec2[] (vec2(0.0), vec2(0.001, 0.001), vec2(0.001, -0.001), vec2(-0.001, 0.001), vec2(-0.001, -0.001));
#else
#ifdef HQ_SMOOTH_SHADOW
  const float shadow_weight[4] = float[] (0.51, 0.26, 0.14, 0.09);
#endif
#endif
float shadowMapping(in SurfaceStruct sr, float alpha, out vec4 shadow_color, float soft_scale) {
	if(sr.dist > 0.9)
		return extShadow;
	float shade = 0.0;
	float angle = dot(lightPosition, sr.normal);

	bool is_plant = (abs(mask.aux.g - 0.22) < 0.05);

  if(angle <= 0.01 && alpha > 0.99 && is_plant && !mask.iswater) {
    shade = 1.0;
	}	else {
    vec4 shadowposition = shadowModelView * sr.worldPosition;
		shadowposition = shadowProjection * shadowposition;
		float edgeX = abs(shadowposition.x) - 0.9;
		float edgeY = abs(shadowposition.y) - 0.9;
		float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
		float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
		shadowposition.xy /= distortFactor;
		shadowposition /= shadowposition.w;
		shadowposition = shadowposition * 0.5 + 0.5;

    #ifdef DRSOE_SS
      float soft_shade = 0.0;
      for (int i = 0; i < 4; i++) {
        float temp_shade = 0.0;
        for (int j = 0; j < 5; j++) {
          float shadowDepth = textureLod(shadowtex1, shadowposition.st + shadow_disp[j] * float(i), float(i)).z;

          if(shadowDepth + 0.0001 < shadowposition.z)
            if (i != 0)
              temp_shade += 1.0 * shadow_weight[i] * clamp(0.0, abs(shadowDepth - shadowposition.z) * far * 2.0 * soft_scale, 1.0);
            else
              temp_shade += 1.0 * shadow_weight[i];
        }
        temp_shade *= 0.2;
        soft_shade += temp_shade;
        if (soft_shade >= 0.99) break;
      }
      shade = soft_shade;

      shadow_color = texture(shadowcolor0, shadowposition.st) * 0.7 + textureLod(shadowcolor0, shadowposition.st, 1.0) * 0.3;
    #else
    #ifdef HQ_SMOOTH_SHADOW
      float soft_shade = 0.0;
      for (int i = 0; i < 4; i++) {
        soft_shade += (shadow2DLod(shadowtex1, vec3(shadowposition.st, shadowposition.z - 0.00001), float(i)).z) * shadow_weight[i];
      }
      shade = soft_shade;

      shadow_color = texture(shadowcolor0, shadowposition.st) * 0.7 + textureLod(shadowcolor0, shadowposition.st, 1.0) * 0.3;
      shade = 1.0 - shade;
    #else
      shade = 1.0 - shadow2D(shadowtex1, vec3(shadowposition.st, shadowposition.z - 0.00001)).z;
      shadow_color = texture(shadowcolor0, shadowposition.st);
    #endif
    #endif
		if(angle < 0.2 && alpha > 0.99 && is_plant && !mask.iswater)
		   shade = max(shade, pow(1.0 - (angle - 0.1) * 10.0, 2));
		shade -= max(0.0, edgeX * 10.0);
		shade -= max(0.0, edgeY * 10.0);
  }
	shade -= clamp((sr.dist - 0.7) * 5.0, 0.0, 1.0);
	shade = clamp(shade, 0.0, 1.0);
	return max(shade, extShadow);
}

float water_wave_adjust(vec3 posxz) {

	float wave = 0.0;

	float factor = 1.0;
	float amplitude = 0.2;
	float speed = 5.5;
	float size = 0.2;

	float px = posxz.x * 0.02f + 250.0f;
	float py = posxz.z * 0.02f  + 250.0f;

	float fpx = abs(fract(px*20.0)-0.5)*2.0;
	float fpy = abs(fract(py*20.0)-0.5)*2.0;

	float d = length(vec2(fpx,fpy));

	for (int i = 1; i < 6; i++) {
		wave -= d*factor*sin( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor *= 0.5;
	}

	factor = 1.0;
	px = -posxz.x * 0.02 + 250.0;
	py = -posxz.z / 150 - 250.0;
	fpx = abs(fract(px*20.0)-0.5)*2.0;
	fpy = abs(fract(py*20.0)-0.5)*2.0;

	d = length(vec2(fpx,fpy));
	float wave2 = 0.0;

	for (int i = 1; i < 6; i++) {
		wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor *= 0.5;
	}

	return amplitude*wave2+amplitude*wave;
}

#ifdef TEST_CLOUD
  float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = smoothstep(0.0, 1.0, f);

    vec2 uv = (p.xy+vec2(37.0, 17.0)*p.z) + f.xy;
    float v1 = texture(noisetex, (uv)/256.0, -100.0 ).x;
    float v2 = texture(noisetex, (uv + vec2(37.0, 17.0))/256.0, -100.0 ).x;
    return mix(v1, v2, f.z);
  }

  float CLOUD_HEIGHT = 185;
  float CLOUD_HEIGHT_CEILING = 255;
  #define CLOUD_SCALE 3.4

  float cloud_noise(vec3 worldPos) {
    vec3 coord = worldPos;
    coord.x += frameTimeCounter * 15.0;
    coord *= 0.002;
    float n  = noise(coord) * 0.5;   coord *= 3.0;
          n += noise(coord) * 0.25;  coord *= 3.01;
          n += noise(coord) * 0.125;
    n = max(n - 0.5, 0.0) * (1.0 / (1.0 - 0.5));

    return n;
  }

  vec3 cloud(vec3 color, vec3 spos, in vec3 direction, float dist) {
    vec4 t_color = vec4(0);

    direction = normalize(direction);
    float bias = dot(direction, vec3(0, 1, 0));
    float am = 0;

    bool var_l = false;

    vec3 test_point = spos;
    if (spos.y > CLOUD_HEIGHT_CEILING) {
      if (direction.y >= 0)
        return color;
      test_point += (direction / abs(direction.y)) * abs(CLOUD_HEIGHT_CEILING - spos.y);
      direction /= abs(direction.y);
    } else if (spos.y < CLOUD_HEIGHT) {
      if (direction.y <= 0)
        return color;
      test_point += (direction / direction.y) * (CLOUD_HEIGHT - spos.y);
      direction /= direction.y;
    } else {
      var_l = true;
    }

    vec3 cloud_c = skyColor * 1.2;

    for (int i = 0; i < 32; i++) {
      if (am > 0.99)
        break;

      float l = length(test_point - spos);
      if ((dist < 313) && (dist * far < l))
        break;

      float step_length;
      if (var_l)
        step_length = float(i) * 0.5;
      else
        step_length = min((CLOUD_HEIGHT_CEILING - CLOUD_HEIGHT) / 32 / abs(direction.y), float(i));

      float d = 0.0;
      if (test_point.y > CLOUD_HEIGHT && test_point.y < CLOUD_HEIGHT_CEILING)
        d = cloud_noise(test_point * CLOUD_SCALE) * 0.35 * clamp(0.0, abs(test_point.y - CLOUD_HEIGHT), 6.0) * 0.1 * step_length;
      am += d;

      test_point += direction * step_length;
    }

    float redution = 1.0 - clamp(0.0, length(test_point - spos) / 8192, 1.0);
      redution = clamp(0.0, redution, 1.0);
    am = clamp(0.0, am, 1.0);
    return mix(color, cloud_c,  am * redution);
  }
#endif

float water_wave_adjust(vec3 posxz, float dep) {

	float wave = 0.0;

	float factor = 1.1;
	float amplitude = 0.19;
	float speed = 5.4;
	float size = 0.27;

	float px = posxz.x/50.0 + 250.0;
	float py = posxz.z/50.0  + 250.0;

	float fpx = abs(fract(px*20.0)-0.5)*2.0;
	float fpy = abs(fract(py*20.0)-0.5)*2.0;

	float d = length(vec2(fpx,fpy));

	for (int i = 1; i < 6; i++) {
		wave -= d*factor*sin( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor *= 0.5;
	}

	factor = 1.0;
	px = -posxz.x/50.0 + 250.0;
	py = -posxz.z/150.0 - 250.0;
	fpx = abs(fract(px*20.0)-0.5)*2.0;
	fpy = abs(fract(py*20.0)-0.5)*2.0;

	d = length(vec2(fpx,fpy));
	float wave2 = 0.0;

	for (int i = 1; i < 6; i++) {
		wave2 -= d*factor*cos( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
	}

	return amplitude*wave2+amplitude*wave;
}

#ifdef SSADDAO
const float AO_weight[4] = float[] (0.0, 0.53, 0.31, 0.26);
const vec2 AO_offset[4] = vec2[] (vec2(0.02, 0.0), vec2(-0.02, 0.0), vec2(0.0, 0.05), vec2(0.0, -0.05));
float AO(in SurfaceStruct s) {
  float am = 0.95;
  float cd = texture(depthtex1, texcoord.st).x;
  for (int a = 1; a < 4; a++) {
    float rd = 0;
    for (int i = 0; i < 4; i++) {
      vec2 adj_st1 = texcoord.st + AO_offset[i] * a;
      adj_st1.s = clamp(0.0, adj_st1.s, 1.0);
      adj_st1.s = clamp(0.0, adj_st1.s, 1.0);

      vec2 adj_st2 = texcoord.st - AO_offset[i] * a;
      adj_st2.s = clamp(0.0, adj_st2.s, 1.0);
      adj_st2.s = clamp(0.0, adj_st2.s, 1.0);

      float s1 = textureLod(depthtex1, adj_st1, float(a)).y;
      float s2 = textureLod(depthtex1, adj_st2, float(a)).y;
      if (abs(s1 - s2) > 1 / far) {
        rd += (s1 + s2) * (1 - abs(s1 - s2) * 12) + cd * 2 * abs(s1 - s2) * 12;
      } else {
        rd += s1 + s2;
      }
    }
    rd *= 0.125;
    am += clamp(-0.1, clamp(-2.0, (rd - cd) * far, 0.2) * AO_weight[a], 0.1);
  }
  return am;
}
#endif

float sky_lightmap;

// ===========================================================================
//  MAIN Function
// ===========================================================================
// *  Everything starts here
// ===========================================================================
void main() {
	color = texture(gcolor, texcoord.st);

  mask.aux = texture(gaux1, texcoord.st);
  mask.blockId = mask.aux.g * 256.0f;

  mask.iswater = (abs(mask.aux.g - 0.125f) < 0.002f);
  mask.issky = ((mask.aux.r < 0.001f) && (mask.aux.g < 0.001f) && (mask.aux.b < 0.001f));
  mask.issun = mask.issky && (abs(mask.aux.b - 0.31f) < 0.002f);
  mask.ishand = (mask.aux.g > 0.98f);
  mask.is_stained_glass = (mask.aux.g > 0.895f) && (mask.aux.g < 0.905f);

  sky_lightmap = pow(mask.aux.r,3.0);

  if (isEyeInWater)
    mask.iswater = !mask.iswater;

  float transition_fading = 1.0-(clamp((worldTime-12000.0)/300.0,0.0,1.0)-clamp((worldTime-13000.0)/300.0,0.0,1.0) + clamp((worldTime-22800.0)/200.0,0.0,1.0)-clamp((worldTime-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows

	surface.normal = normalDecode(texture(gnormal, texcoord.st).rg);
  surface_nw.normal = normalDecode(texture(gaux2, texcoord.st).rg);
	float depth = texture(depthtex1, texcoord.st).x;
  float depth_nw = texture(depthtex0, texcoord.st).x;

	surface.viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
	surface.viewPosition /= surface.viewPosition.w;
  surface_nw.viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth_nw - 1.0, 1.0f);
	surface_nw.viewPosition /= surface_nw.viewPosition.w;

	surface.worldPosition = gbufferModelViewInverse * (surface.viewPosition + vec4(surface.normal * 0.05 * sqrt(abs(surface.viewPosition.z)), 0.0));
  vec3 wpos = surface.worldPosition.xyz + cameraPosition;
  surface_nw.worldPosition = gbufferModelViewInverse * (surface.viewPosition + vec4(surface.normal * 0.05 * sqrt(abs(surface.viewPosition.z)), 0.0));

  surface.dist = length(surface.worldPosition.xyz) / far;
  surface_nw.dist = length(surface_nw.worldPosition.xyz) / far;


  float r_shade = 0.0;

  if (mask.issky) {
  //  color.rgb = mix(skyColor.rgb, vec3(0.3, 0.44, 0.86) * length(suncolor) / length(suncolor_noon), clamp(0.0, dot(normalize(worldPosition.xyz), vec3(0.0, 1.0, 0.0)) - 0.2, 1.0));

    surface.dist = 317; // MAGIC
  } else {
    float shade = 0.0;
    // ===========================================================================
    //  WATER
    // ===========================================================================
    vec4 shadow_color = vec4(1.0);
    if (mask.iswater) {
      float deltaPos = 0.1;
      float depth_diff = abs(depth_nw - depth);
      float h0 = water_wave_adjust(wpos, depth_diff);

      float under_water_shade = clamp(shadowMapping(surface, color.a, shadow_color, 4.0), 0.0, 1.0) * 0.88;
      under_water_shade += (h0 * 1.1) * 0.6 * (1 - under_water_shade);

      if (!isEyeInWater) {
        r_shade = shadowMapping(surface_nw, color.a, shadow_color, 3.0);
        shade = under_water_shade + r_shade * 0.12;
      } else {
        r_shade = under_water_shade;
        shade = r_shade;
      }
    } else {
      r_shade = shadowMapping(surface, color.a, shadow_color, 1.0);// * 0.5 + shadowMapping(worldPosition + vec4(lightPosition * normal, 0) * 0.3, dist, normal, color.a) * 0.5;

      shade = r_shade;
    }

    // ===========================================================================
    //  Shading & Lighting
    // ===========================================================================
    // Torchlight properties.
    float torchDistanceOutsideDay   = 2.6f * sky_lightmap        * (TimeSunrise + TimeNoon + TimeSunset);
    float torchDistanceInsideDay    = 2.4f  * (1.0-sky_lightmap) * (TimeSunrise + TimeNoon + TimeSunset);

    float torchBrightnessOutsideDay = 0.65f  * sky_lightmap       * (TimeSunrise + TimeNoon + TimeSunset);
    float torchBrightnessInsideDay  = 0.83f * (1.0-sky_lightmap) * (TimeSunrise + TimeNoon + TimeSunset);

    float torchDistanceNight        = 2.4f  * TimeMidnight;
    float torchBrightnessNight      = 0.86f * TimeMidnight;

    float torchDistance          = torchDistanceOutsideDay   + torchDistanceInsideDay   + torchDistanceNight;
    float torchBrightness        = torchBrightnessOutsideDay + torchBrightnessInsideDay + torchBrightnessNight;

    float ao_am = AO(surface);

    vec3 torchcolor = vec3(1.95, 1.31, 0.43);
    float tlight = clamp(mask.aux.b, 0.0, 1.0);
    vec3 torchlight = pow(tlight, torchDistance) * torchBrightness * torchcolor * ao_am;

    float min_light = min(0.45 - float(eyeBrightnessSmooth.y + eyeBrightnessSmooth.x * 0.65) * 0.0014, ao_am);

    vec3 sun_l = suncolor * (1 - shade) * (1 - wetness * 0.5);
    vec3 amb_color = clamp(suncolor, vec3(min_light), vec3(1.25));

    if (shade < 0.999 && shadow_color.a > 0.49 && shadow_color.a < 0.51)
      sun_l = (1 - shade) * shadow_color.rgb * (length(suncolor) * (1.0 - wetness * 0.86) / length(shadow_color.rgb));

    vec3 light = clamp(amb_color * 0.35 + sun_l * 0.34 + torchlight, vec3(min_light), vec3(1.8));

    color.rgb *= 1 - wetness * 0.25;

    color.rgb *= light;
  }

  #ifdef TEST_CLOUD
  if (!mask.ishand)
    color.rgb = cloud(color.rgb, cameraPosition, normalize(surface.worldPosition).xyz, surface.dist);
  #endif

  // ===========================================================================
  //  BLOOM
  // ===========================================================================
  #ifdef BLOOM
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 highlight = color.rgb * max(brightness - 0.25, 0.0);
  #endif

  // ===========================================================================
  //  OUT
  // ===========================================================================
/* DRAWBUFFERS:01 */
	gl_FragData[0] = vec4(color.rgb, r_shade);
  #ifdef BLOOM
    gl_FragData[1] = vec4(highlight, 1.0);
  #endif
}
