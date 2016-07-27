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

const int RGB8 = 0;
const int colortex3Format = RGB8;
const bool gcolorMipmapEnabled = true;

#define WATER_REFLECTIONS

in vec4 texcoord;
in vec3 lightPosition;
invariant flat in vec3 sunVec;
invariant flat in vec3 moonVec;
invariant flat in vec3 upVec;
in vec3 suncolor;
in float SdotU;
in float MdotU;
in float sunVisibility;
in float moonVisibility;
in float handItemLight;

invariant flat  in float TimeSunrise;
invariant flat  in float TimeNoon;
invariant flat  in float TimeSunset;
invariant flat  in float TimeMidnight;

uniform sampler2D noisetex;
uniform sampler2D colortex1;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gcolor;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D gnormal;
uniform sampler2D gdepth;
uniform vec3 sunPosition;
uniform vec3 upPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform bool isEyeInWater;
uniform int worldTime;
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;
uniform float frameTimeCounter;
uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; SEARCHPOINT+= DIRVEC * SIGN; uv = getScreenCoordByViewCoord(SEARCHPOINT); sampleDepth = linearizeDepth(textureLod(depthtex0, uv, 0.0).x); testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); SIGN = sign(sampleDepth - testDepth);

const float offset[9] = float[] (0.0, 1.4896, 3.4757, 5.4619, 7.4482, 9.4345, 11.421, 13.4075, 15.3941);
const float weight[9] = float[] (0.066812, 0.129101, 0.112504, 0.08782, 0.061406, 0.03846, 0.021577, 0.010843, 0.004881);

float rainStrength2 = clamp(wetness, 0.0f, 1.0f)/1.0f;

float matflag = texture(gaux1,texcoord.xy).g;
vec3 fragpos = vec3(texcoord.st, texture(depthtex0, texcoord.st).r);

struct SurfaceStruct {
  vec4 worldPosition;
  vec3 normal;
  vec4 viewPosition;

  float dist;
} surface, surface_nw;

vec4 color;

vec3 normalDecode(vec2 enc) {
  vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
  float l = dot(nn.xyz,-nn.xyw);
  nn.z = l;
  nn.xy *= sqrt(l);
  return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

vec2 getScreenCoordByViewCoord(vec3 viewCoord) {
    vec4 p = vec4(viewCoord, 1.0);
    p = gbufferProjection * p;
    p /= p.w;
    if(p.z < -1 || p.z > 1)
        return vec2(-1.0);
    p = p * 0.5f + 0.5f;
    return p.st;
}

float linearizeDepth(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
    vec4 p = vec4(viewCoord, 1.0);
    p = gbufferProjection * p;
    p /= p.w;
    return linearizeDepth(p.z * 0.5 + 0.5);
}

vec4 waterRayTarcing(vec3 startPoint, vec3 direction, vec3 color) {
    const float stepBase = 0.025;
    vec3 testPoint = startPoint;
    direction *= stepBase;
    bool hit = false;
    vec4 hitColor = vec4(0.0);
    vec3 lastPoint = testPoint;
    for(int i = 0; i < 40; i++) {
      testPoint += direction * pow(float(i + 1), 1.46);
      vec2 uv = getScreenCoordByViewCoord(testPoint);
      if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        hit = true;
        break;
      }
      float sampleDepth = textureLod(depthtex0, uv, 0.0).x;
      sampleDepth = linearizeDepth(sampleDepth);
      float testDepth = getLinearDepthOfViewCoord(testPoint);
      if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i))){
        vec3 finalPoint = lastPoint;
        float _sign = 1.0;
        direction = testPoint - lastPoint;
        BISEARCH(finalPoint, direction, _sign);
        BISEARCH(finalPoint, direction, _sign);
        //BISEARCH(finalPoint, direction, _sign);
        //BISEARCH(finalPoint, direction, _sign);
        uv = getScreenCoordByViewCoord(finalPoint);
        hitColor = vec4(textureLod(gcolor, uv, 0.0).rgb, 1.0);
        hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0);
        hit = true;
        break;
      }
      lastPoint = testPoint;
    }
    if(!hit) {
      vec2 uv = getScreenCoordByViewCoord(lastPoint);
      float testDepth = getLinearDepthOfViewCoord(lastPoint);
      float sampleDepth = textureLod(depthtex0, uv, 0.0).x;
      sampleDepth = linearizeDepth(sampleDepth);
      if(testDepth - sampleDepth < 0.5) {
        hitColor = vec4(textureLod(gcolor, uv, 0.0).rgb, 1.2);
        hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0);
      }
    }
    return hitColor;
}

float water_wave_adjust(vec3 posxz, float dep) {

	float wave = 0.0;

	float factor = 1.1;
	float amplitude = 0.27;
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

vec4 aux = texture(gaux1, texcoord.st);
float blockId = aux.g * 256;

bool iswater = (abs(aux.g - 0.125) < 0.002);
bool isglass = (abs(aux.g - 0.130) < 0.002);
bool issky = (aux.g < 0.01) && (aux.r < 0.001) && (aux.b < 0.001);
bool isentity = (aux.g < 0.01) && !issky;

vec3 blur(sampler2D image, vec2 uv, vec2 direction) {
   vec3 color = texture2D(image, uv).rgb * weight[0];
   for(int i = 1; i < 9; i++)
   {
       color += textureLod(image, uv + direction * offset[i], 3.0).rgb * weight[i];
       color += textureLod(image, uv - direction * offset[i], 3.0).rgb * weight[i];
   }
   return color;
}

float sky_lightmap = pow(aux.r,3.0);

float iswet;

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

vec4 refbl(vec4 a, vec4 b) {
  vec4 c;
  c.r = a.r * b.r;
  c.g = a.g * b.g;
  c.b = a.b * b.b;
  c.a = a.a * b.a;
  return c;
}

void main() {

  if (isEyeInWater)
    iswater = !iswater;

  vec3 blur_color = blur(colortex1, texcoord.st, vec2(1.0, 0.0) / vec2(viewWidth, viewHeight));

  vec4 color;
  if (iswater || isglass) {
    color = textureLod(gcolor, texcoord.st, 2.0);
    color.rgb = mix(color.rgb, blur_color, 0.4);
  } else
    color = texture(gcolor, texcoord.st);

  float shade = color.a;
  color = vec4(color.rgb, 1.0);

  float transition_fading = 1.0-(clamp((worldTime-12000.0)/300.0,0.0,1.0)-clamp((worldTime-13000.0)/300.0,0.0,1.0) + clamp((worldTime-22800.0)/200.0,0.0,1.0)-clamp((worldTime-23400.0)/200.0,0.0,1.0));	//fading between sun/moon shadows

	surface.normal = normalDecode(texture(gnormal, texcoord.st).rg);
  surface_nw.normal = normalDecode(texture(gaux2, texcoord.st).rg);
	float depth = texture(depthtex1, texcoord.st).x;
  float depth_nw = texture(depthtex0, texcoord.st).x;

  iswet = wetness * pow(sky_lightmap, 10.0) * sqrt(0.5 + max(dot(surface.normal, normalize(upPosition)), 0.0));

	surface.viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth - 1.0, 1.0f);
	surface.viewPosition /= surface.viewPosition.w;
  surface_nw.viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 2.0 * depth_nw - 1.0, 1.0f);
	surface_nw.viewPosition /= surface_nw.viewPosition.w;

	surface.worldPosition = gbufferModelViewInverse * (surface.viewPosition + vec4(surface.normal * 0.05 * sqrt(abs(surface.viewPosition.z)), 0.0));
  surface_nw.worldPosition = gbufferModelViewInverse * (surface_nw.viewPosition + vec4(surface_nw.normal * 0.05 * sqrt(abs(surface_nw.viewPosition.z)), 0.0));

  surface.dist = length(surface.worldPosition.xyz) / far;
  surface_nw.dist = length(surface_nw.worldPosition.xyz) / far;

  if (issky) {
  } else {
    if (!isEyeInWater)
    // ===========================================================================
    //  WATER
    // ===========================================================================
    if (iswater) {
      #ifdef WATER_REFLECTIONS

      vec3 watercolor = skyColor * (0.6 - iswet / 4); // Water got dark after rain

      float deltaPos = 0.1;
      float depth_diff = abs(depth_nw - depth);
      vec3 wpos = surface_nw.worldPosition.xyz + cameraPosition;
  		float h0 = water_wave_adjust(wpos, depth_diff);
  		float h1 = water_wave_adjust(wpos + vec3(deltaPos,0.0,0.0), depth_diff);
  		float h2 = water_wave_adjust(wpos + vec3(-deltaPos,0.0,0.0), depth_diff);
  		float h3 = water_wave_adjust(wpos + vec3(0.0,0.0,deltaPos), depth_diff);
  		float h4 = water_wave_adjust(wpos + vec3(0.0,0.0,-deltaPos), depth_diff);

  		float xDelta = (h1-h0)+(h0-h2);
  		float yDelta = (h3-h0)+(h0-h4);
      surface_nw.normal += vec3(xDelta * 0.074, 0, yDelta * 0.074);

      watercolor *= 1 + (yDelta + xDelta) * 0.3;

      float mR = texture(gaux1, texcoord.st + vec2(xDelta, yDelta) / 13.5).g;

      if (mR > 0.12 && mR < 0.13) {
        vec2 cR = texcoord.st + vec2(xDelta, yDelta) / 13.5;
          cR.s = clamp(cR.s, 1.0 / viewWidth, 1.0 - 1.0 / viewWidth);
          cR.t = clamp(cR.t, 1.0 / viewHeight, 1.0 - 1.0/viewHeight);

        color.rgb = textureLod(gcolor, texcoord.st + vec2(xDelta, yDelta) / 13.5, 1 - (surface.dist - surface_nw.dist)).rgb;
        /*float R = texture(gcolor, texcoord.st + vec2(xDelta * 0.9, yDelta * 1.0) / 13.5).r;
        float G = texture(gcolor, texcoord.st + vec2(xDelta * 0.9, yDelta * 1.1) / 13.5).g;
        float B = texture(gcolor, texcoord.st + vec2(xDelta * 1.1, yDelta * 0.9) / 13.5).b;
        color.rgb = vec3(R,G,B);*/
      }

      vec3 viewRefRay = reflect(normalize(surface_nw.viewPosition.xyz), surface_nw.normal);

      vec4 ref_color = refbl(waterRayTarcing(surface_nw.viewPosition.xyz + surface_nw.normal * (-surface_nw.viewPosition.z / far * 0.2 + 0.05), viewRefRay, color.rgb), vec4(0.85, 0.90, 0.95, 1.0));

      vec3 sun_ref = suncolor * (1.0 - wetness * 0.86) * max(pow(dot(normalize(lightPosition.xyz), normalize(viewRefRay.xyz)), 11.0), 0.0) * (1 - shade);

      float fresnel = 0.02 + 0.98 * pow(1.0 - dot(viewRefRay, surface_nw.normal), 5.0);
      float refract_amount = clamp((1 - fresnel) * (12 - clamp((surface.dist - surface_nw.dist) * far, 0.0, 12.0)) / 12, 0.0, 1.0);
      color.rgb = (color.rgb * refract_amount * 0.76) + (ref_color.rgb * ref_color.a * (1 - refract_amount) * vec3(0.6,0.7,0.9)) + watercolor * (1 - ref_color.a * (1 - refract_amount) - refract_amount) + sun_ref;

      #endif
    } else if (!isentity) {
      vec4 specular = texture(gaux3, texcoord.st);

      float ref_cr;
      float sun_cr;
      float ang = dot(surface.normal, upVec) * 0.5 + 0.5;
      if (length(specular.rgb) < 0.1) {
        ref_cr = clamp(0.0, iswet * ang * 0.43, 1.0);
        sun_cr = clamp(0.0, iswet * ang * 0.45, 1.0);
      } else {
        ref_cr = clamp(0.0, iswet * ang * specular.g + specular.r * 0.77, 1.0);
        sun_cr = clamp(0.0, iswet * ang * specular.g + specular.b * 0.77, 1.0);
      }

    //  vec3 ref_color = vec3(0.44) * wetness_cr + texture2D(gaux3, texcoord.st).rgb;

      vec4 ref_color = vec4(0.0);
      vec3 sun_ref = vec3(0.0);
      vec3 viewRefRay = reflect(normalize(surface.viewPosition.xyz), surface.normal);
      if (ref_cr > 0.05)
        ref_color = refbl(waterRayTarcing(surface.viewPosition.xyz + surface.normal * (-surface.viewPosition.z / far * 0.2 + 0.05), viewRefRay, color.rgb), color * 0.7 + vec4(max(specular.b, specular.g) * 0.75));
      if (sun_cr > 0.05)
        sun_ref = suncolor * (1.0 - wetness * 0.86) * max(pow(dot(normalize(lightPosition.xyz), normalize(viewRefRay.xyz)), 11.0), 0.0) * (1 - shade) * sun_cr;

      color.rgb += sun_ref * sun_cr + ref_color.rgb * ref_color.a * ref_cr;
    }

    color.rgb = mix(color.rgb, gl_Fog.color.rgb * skyColor, clamp(pow(surface.dist, (1 - wetness * 0.5) * 3.95 - wetness), 0.0, 1.0));
    float ddist = surface.dist;
      ddist *= ddist;
      ddist *= ddist;
      ddist *= ddist;
      ddist *= ddist;
    color.rgb = mix(color.rgb, skyColor, clamp(ddist, 0.0, 1.0));
    color.rgb = rgbToHsl(color.rgb);
    color.g = color.g * (1 - wetness) + color.g * (wetness) * clamp(0.3, 1 - color.g * surface.dist * 2, 1.0);
    color.rgb = hslToRgb(color.rgb);
  }

/* DRAWBUFFERS:03 */
  gl_FragData[0] = color;
  gl_FragData[1] = vec4(blur_color, 1.0);
}
