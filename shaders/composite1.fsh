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
#extension GL_ARB_shader_texture_lod : require

#define PI 3.14159

#define TEST_CLOUD
#define HQ_SMOOTH_SHADOW

#define SHADOW_MAP_BIAS 0.8
const int     RG16 = 0;
const int     RGBA8 = 0;
const int     colortex1Format = RGBA8;
const int     gnormalFormat = RG16;
#ifdef HQ_SMOOTH_SHADOW
  const int     shadowMapResolution     = 2048;
#else
  const int     shadowMapResolution     = 1024;
#endif
const float 	centerDepthHalflife 	  = 2.0f;
const float 	shadowIntervalSize 		  = 6.f;
const float 	wetnessHalflife 		 	  = 500.0f; 	 // Wet to dry.
const float 	drynessHalflife 		 	  = 60.0f;		 // Dry ro wet.
const float		sunPathRotation			 	  = -39.5f;
const float		eyeBrightnessHalflife	  = 8.5f;
const bool    shadowHardwareFiltering = true;
const bool    gcolorMipmapEnabled     = true;
#ifdef HQ_SMOOTH_SHADOW
  const bool    shadowtex1Mipmap        = true;
  const bool    shadowcolor0Mipmap      = true;
#endif
const float   ambientOcclusionLevel   = 1.0;

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
uniform vec3 skyColor;
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
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

in float extShadow;
in vec3 lightPosition;
in vec3 upVec;
in vec3 sunVec;
in vec3 moonVec;
in float SdotU;
in float MdotU;
in float moonVisibility;
in vec4 texcoord;
in float handlight;
in vec3 worldSunPosition;

vec3 normalDecode(vec2 enc) {
  vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
  float l = dot(nn.xyz,-nn.xyw);
  nn.z = l;
  nn.xy *= sqrt(l);
  return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

float edepth(vec2 coord) {
	return texture(depthtex0,coord).z;
}

float luma(vec3 color) {
	return dot(color,vec3(0.3, 0.6, 0.1));
}

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

vec3 nvec3(vec4 pos) {
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos) {
    return vec4(pos.xyz, 1.0);
}

float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;


float timefract = worldTime;
float TimeSunrise  = ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0) + (1.0 - (clamp(timefract, 0.0, 2000.0)/2000.0));
float TimeNoon     = ((clamp(timefract, 0.0, 2000.0)) / 2000.0) - ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0);
float TimeSunset   = ((clamp(timefract, 10000.0, 12000.0) - 10000.0) / 2000.0) - ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0);
float TimeMidnight = ((clamp(timefract, 12000.0, 12750.0) - 12000.0) / 750.0) - ((clamp(timefract, 23000.0, 24000.0) - 23000.0) / 1000.0);

vec4 aux = texture(gaux1, texcoord.st);
float blockId = aux.g * 256;

bool iswater = (abs(aux.g - 0.125) < 0.002);
bool issky = ((aux.r < 0.001) && (aux.g < 0.001) && (aux.b < 0.001));
bool ishand = (aux.g > 0.98);
bool is_stained_glass = (aux.g > 0.895) && (aux.g < 0.905);

#ifdef HQ_SMOOTH_SHADOW
  const float shadow_weight[4] = float[] (0.51, 0.26, 0.14, 0.09);
#endif
float shadowMapping(vec4 worldPosition, float dist, vec3 normal, float alpha, out vec4 shadow_color) {
	if(dist > 0.9)
		return extShadow;
	float shade = 0.0;
	float angle = dot(lightPosition, normal);

	bool is_plant = (abs(blockId - 31.0) < 0.1 || abs(blockId - 37.0) < 0.1 || abs(blockId - 38.0) < 0.01 || abs(blockId - 18.0) < 0.01 || abs(blockId - 106.0) < 0.01 || abs(blockId - 161.0) < 0.01 || abs(blockId - 175.0) < 0.01);

  if(angle <= 0.01 && alpha > 0.99 && !is_plant && !iswater) {
    shade = 1.0;
	}	else {
    vec4 shadowposition = shadowModelView * worldPosition;
		shadowposition = shadowProjection * shadowposition;
		float edgeX = abs(shadowposition.x) - 0.9;
		float edgeY = abs(shadowposition.y) - 0.9;
		float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
		float distortFactor = (1.0 - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
		shadowposition.xy /= distortFactor;
		shadowposition /= shadowposition.w;
		shadowposition = shadowposition * 0.5 + 0.5;

    #ifdef HQ_SMOOTH_SHADOW
      float soft_shade = 0.0;
      for (int i = 0; i < 4; i++) {
        soft_shade += (shadow2DLod(shadowtex1, vec3(shadowposition.st, shadowposition.z - 0.00001), float(i)).z) * shadow_weight[i];
      }
//      float shadowDepth = texture(shadowtex0, shadowposition.st).z;

      /*shade = 1.0;
      if(shadowDepth + 0.0001 < shadowposition.z)
        shade = (shadowposition.z - shadowDepth) * far;
*/
      shade = soft_shade;

      shadow_color = texture(shadowcolor0, shadowposition.st) * 0.7 + textureLod(shadowcolor0, shadowposition.st, 1.0) * 0.3;
      shade = 1.0 - shade;
    #else
      shade = 1.0 - shadow2D(shadowtex1, vec3(shadowposition.st, shadowposition.z - 0.00001)).z;
      shadow_color = texture(shadowcolor0, shadowposition.st);
    #endif
		if(angle < 0.2 && alpha > 0.99 && !is_plant && !iswater)
		   shade = max(shade, pow(1.0 - (angle - 0.1) * 10.0, 2));
		shade -= max(0.0, edgeX * 10.0);
		shade -= max(0.0, edgeY * 10.0);
  }
	shade -= clamp((dist - 0.7) * 5.0, 0.0, 1.0);
	shade = clamp(shade, 0.0, 1.0);
	return max(shade, extShadow);
}

float water_wave_adjust(vec3 posxz) {

	float wave = 0.0;

	float factor = 1.0;
	float amplitude = 0.2;
	float speed = 5.5;
	float size = 0.2;

	float px = posxz.x/50.0 + 250.0;
	float py = posxz.z/50.0  + 250.0;

	float fpx = abs(fract(px*20.0)-0.5)*2.0;
	float fpy = abs(fract(py*20.0)-0.5)*2.0;

	float d = length(vec2(fpx,fpy));

	for (int i = 1; i < 6; i++) {
		wave -= d*factor*sin( (1/factor)*px*py*size + 1.0*frameTimeCounter*speed);
		factor /= 2;
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
      //if (direction.y >= 0)
      //  return color;
      test_point += (direction / abs(direction.y)) * abs(CLOUD_HEIGHT_CEILING - spos.y);
      //direction /= direction.y;
    } else if (spos.y < CLOUD_HEIGHT) {
      if (direction.y <= 0)
        return color;
      test_point += (direction / direction.y) * (CLOUD_HEIGHT - spos.y);
      direction /= direction.y;
    } else {
      var_l = true;
    }

    for (int i = 0; i < 32; i++) {
      if (t_color.a > 0.99)
        break;

      float l = length(test_point - spos);
      if ((dist < 313) && (dist * far < l))
        break;

      if (test_point.y > CLOUD_HEIGHT && test_point.y < CLOUD_HEIGHT_CEILING)
        am += cloud_noise(test_point * CLOUD_SCALE) * 0.35 * clamp(0.0, abs(test_point.y - CLOUD_HEIGHT), 6.0) / 2.0;

      if (var_l)
        test_point += direction * i;
      else
        if (direction.y >= 0)
          test_point += min((CLOUD_HEIGHT_CEILING - CLOUD_HEIGHT) / 32 / direction.y, float(i)) * direction;
        else
          test_point += min((CLOUD_HEIGHT_CEILING - CLOUD_HEIGHT) / 32 / abs(direction.y), float(i)) * direction;

    }

    float redution = 1.0 - clamp(0.0, length(test_point - spos) / 1512, 1.0);
      redution = clamp(0.0, redution, 1.0);
    am = clamp(0.0, am, 1.0);
    return color + (vec3(am) * skyColor) * redution;
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
		factor /= 2;
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

float sky_lightmap = pow(aux.r,3.0);

// ===========================================================================
//  MAIN Function
// ===========================================================================
// *  Everything starts here
// ===========================================================================
void main() {
	vec4 color = texture(gcolor, texcoord.st);

  if (isEyeInWater)
    iswater = !iswater;

  float transition_fading = 1.0-(clamp((worldTime-12000.0)/300.0,0.0,1.0)-clamp((worldTime-13000.0)/300.0,0.0,1.0) + clamp((worldTime-22800.0)/200.0,0.0,1.0)-clamp((worldTime-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows

	vec3 normal = normalDecode(texture(gnormal, texcoord.st).rg);
  vec3 normal_nw = normalDecode(texture(gaux2, texcoord.st).rg);
	float depth = texture(depthtex1, texcoord.st).x;
  float depth_nw = texture(depthtex0, texcoord.st).x;

	vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
	viewPosition /= viewPosition.w;
  vec4 viewPosition_nw = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth_nw - 1.0, 1.0f);
	viewPosition_nw /= viewPosition_nw.w;

	vec4 worldPosition = gbufferModelViewInverse * (viewPosition + vec4(normal * 0.05 * sqrt(abs(viewPosition.z)), 0.0));
  vec3 wpos = worldPosition.xyz + cameraPosition;
  vec4 worldPosition_nw = gbufferModelViewInverse * (viewPosition_nw + vec4(normal_nw * 0.05 * sqrt(abs(viewPosition_nw.z)), 0.0));

  float dist = length(worldPosition.xyz) / far;
  float dist_nw = length(worldPosition_nw.xyz) / far;

  vec3 suncolor_sunrise = vec3(2.52, 1.2, 0.9) * TimeSunrise;
  vec3 suncolor_noon = vec3(2.52, 2.25, 2.0) * TimeNoon;
  vec3 suncolor_sunset = vec3(2.52, 1.0, 0.7) * TimeSunset;
  vec3 suncolor_midnight = vec3(0.3, 0.7, 1.3) * 0.37 * TimeMidnight * (1.0 - rainStrength2 * 1.0);

  vec3 suncolor = suncolor_sunrise + suncolor_noon + suncolor_sunset + suncolor_midnight;
    suncolor.r = pow(suncolor.r, 1.0 - rainStrength2 * 0.5);
    suncolor.g = pow(suncolor.g, 1.0 - rainStrength2 * 0.5);
    suncolor.b = pow(suncolor.b, 1.0 - rainStrength2 * 0.5);

  float r_shade = 0.0;

  if (issky) {
    dist = 317; // MAGIC
  } else {
    float shade = 0.0;
    // ===========================================================================
    //  WATER
    // ===========================================================================
    vec4 shadow_color = vec4(1.0);
    if (iswater) {
      float deltaPos = 0.1;
      float depth_diff = abs(depth_nw - depth);
      float h0 = water_wave_adjust(wpos, depth_diff);

      float under_water_shade = clamp(shadowMapping(worldPosition, dist, normal, color.a, shadow_color), 0.0, 1.0) * 0.42 + h0;

      if (!isEyeInWater) {
        r_shade = shadowMapping(worldPosition_nw, dist_nw, normal_nw, color.a, shadow_color);
        shade = under_water_shade + r_shade * 0.58;
      } else {
        r_shade = under_water_shade;
        shade = r_shade;
      }
    } else {
      r_shade = shadowMapping(worldPosition, dist, normal, color.a, shadow_color);// * 0.5 + shadowMapping(worldPosition + vec4(lightPosition * normal, 0) * 0.3, dist, normal, color.a) * 0.5;

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

    vec3 torchcolor = vec3(1.95, 1.31, 0.43);
    float tlight = clamp(aux.b, 0.0, 1.0);
    vec3 torchlight = pow(tlight, torchDistance) * torchBrightness * torchcolor;

    float min_light = 1.15 - float(eyeBrightnessSmooth.y + eyeBrightnessSmooth.x * 0.65) / 560;

    vec3 sun_l = suncolor * (1 - shade) * (1 - wetness * 0.5);
    vec3 amb_color = clamp(suncolor, vec3(min_light), vec3(1.25));

    if (shade < 0.999 && shadow_color.a > 0.49 && shadow_color.a < 0.51)
      sun_l = (1 - shade) * shadow_color.rgb * (length(suncolor) * (1.0 - wetness * 0.86) / length(shadow_color.rgb));

    vec3 light = clamp(amb_color * 0.25 + sun_l * 0.5 + torchlight, vec3(min_light), vec3(1.8));

    color.rgb *= 1 - wetness * 0.25;

    color.rgb *= light;
  }

  #ifdef TEST_CLOUD
  if (!ishand)
    color.rgb = cloud(color.rgb, cameraPosition, normalize(worldPosition).xyz, dist);
  #endif

  // ===========================================================================
  //  BLOOM
  // ===========================================================================
  float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  vec3 highlight = color.rgb * max(brightness - 0.25, 0.0);

  // ===========================================================================
  //  OUT
  // ===========================================================================
/* DRAWBUFFERS:01 */
	gl_FragData[0] = vec4(color.rgb, r_shade);
  gl_FragData[1] = vec4(highlight, 1.0);
}
