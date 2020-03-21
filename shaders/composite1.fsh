#version 120

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

#include "libs/compat.glsl"
#pragma optimize(on)

varying vec2 uv;

#include "GlslConfig"

#define WATER_CAUSTICS

#include "libs/uniforms.glsl"
#include "libs/color.glsl"
#include "libs/encoding.glsl"
#include "libs/vectors.glsl"
#include "libs/Material.frag"
#include "libs/noise.glsl"
#include "libs/Lighting.frag"

Mask mask;
Material frag;

#include "libs/atmosphere.glsl"
#define CrespecularRays

varying vec3 sunLight;
varying vec3 sunraw;
varying vec3 ambientU;

varying vec3 worldLightPosition;

#include "libs/Water.frag"

const bool colortex0MipmapEnabled = true;

uniform vec3 fogColor;

#define SUM4_depth_bias(buf, depth, offset) c = textureGatherOffset(buf, uv, offset); d = step(0.99999, textureGatherOffset(depth, uv, offset)); scatteram += dot(c, vec4(1.0) - d);

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  #ifdef CrespecularRays
  float scatteram = 0.0;
  // Blur and collect scattering
  if (frag.cdepthN >= 1.0) {
    scatteram = texture2D(colortex0, uv).r;
  } else {
    vec4 c, d;
    SUM4_depth_bias(colortex0, depthtex0, ivec2( 0, 1))
    SUM4_depth_bias(colortex0, depthtex0, ivec2( 0,-1))
    SUM4_depth_bias(colortex0, depthtex0, ivec2(-1, 0))
    SUM4_depth_bias(colortex0, depthtex0, ivec2( 1, 0))
    scatteram *= 0.0625;
  }
  #else
  float scatteram = 1.0;
  #endif

  if (isEyeInWater == 0) {
    if (!mask.is_sky || frag.cdepthN <= 1.0) {
      vec3 nwpos = normalize(frag.wpos + vec3(0.0, 1.7, 0.0));
      
      #ifdef CrespecularRays
      float fog_coord = groundFog(min(frag.cdepth / (2048.0 - cloud_coverage * 1512.0), 1.0), cameraPosition.y / 512.0, nwpos);
      float fog_H = groundFogH(min(frag.cdepth / (2048.0 - cloud_coverage * 1512.0), 1.0), cameraPosition.y / 512.0, nwpos);
      color *= 1.0 - fog_coord;
      
      // Blur and collect scattering    
      color += fog_H * scatter(vec3(0., 2e3 + cameraPosition.y, 0.), nwpos, worldLightPosition, 40e3 * scatteram);
      #else
      float fog_coord = groundFog(min(frag.cdepth / (2048.0 - cloud_coverage * 1512.0), 1.0), cameraPosition.y / 512.0, nwpos);
    
      color = mix(color, texture2D(gaux4, project_skybox2uv(nwpos)).rgb, fog_coord);
      #endif
    } else {
      color *= scatteram;
    }
  } else {
    const vec3 waterfogcolor = vec3(0.1,0.511,0.694) * 0.005;
    if (isEyeInWater == 1 && !mask.is_water) {
      float dist_diff_N = min(1.0, frag.cdepth * 0.03125);             // Distance clamped (0.0 ~ 1.0)
  
      #ifdef WATER_CAUSTICS
		  color *= smoothstep(0.0, 1.0, fma(get_caustic(frag.wpos + cameraPosition), 1.1, 0.5));
		  #endif

		  float light_att = luma(fogColor) * 2.0;
		  vec3 waterfog = (luma(sunLight) * light_att) * waterfogcolor;

      float absorption = pow2(2.0 / (dist_diff_N + 1.0) - 1.0);     // Water absorption factor
	  	float scatter_in = (abs(dot(lightPosition, frag.N)) * 0.8 + 0.2);  // Scatter-in factor

      if (mask.is_sky) {
        scatter_in = 1.0;
      }

  		vec3 watercolor = color.rgb
	  	   * pow(vec3(absorption), vec3(3.0, 0.8, 1.0))         // Water absorption color
	  	   * scatter_in;

      color = mix(waterfog, watercolor, absorption);
    }

    color += smoothstep(0.0, 0.1, scatteram) * sunLight * waterfogcolor * 0.5;
  }

/* DRAWBUFFERS:5 */
  gl_FragData[0] = vec4(color, 1.0);
}
