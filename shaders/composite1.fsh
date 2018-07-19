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

void main() {
  vec3 color = texture2D(gaux2, uv).rgb;

  float flag;
  material_sample(frag, uv, flag);

  init_mask(mask, flag, uv);

  if (!mask.is_sky || frag.cdepthN < 0.999) {
    float fog_coord = min(frag.cdepth / (1024.0 - cloud_coverage * 768.0), 1.0);
    color *= 1.0 - fog_coord * 0.8;

    vec3 nwpos = normalize(frag.wpos);

    #ifdef CrespecularRays
    // Blur and collect scattering
    float scatteram  = sum4(textureGather      (colortex0, uv              ));
          scatteram += sum4(textureGatherOffset(colortex0, uv, ivec2(-1, 0)));
          scatteram += sum4(textureGatherOffset(colortex0, uv, ivec2(-1,-1)));
          scatteram += sum4(textureGatherOffset(colortex0, uv, ivec2( 0,-1)));
          scatteram *= 0.0625;
    
    color += texture2D(gaux4, project_skybox2uv(nwpos)).rgb * scatteram;
    #else
    color += texture2D(gaux4, project_skybox2uv(nwpos)).rgb * fog_coord;
    #endif
  }

  if (isEyeInWater == 1 && !mask.is_water) {
    float dist_diff_N = min(1.0, frag.cdepth * 0.0625);             // Distance clamped (0.0 ~ 1.0)
  
    #ifdef WATER_CAUSTICS
		color *= smoothstep(0.0, 1.0, fma(get_caustic(frag.wpos + cameraPosition), 1.1, 0.5));
		#endif

    float absorption = pow2(2.0 / (dist_diff_N + 1.0) - 1.0);     // Water absorption factor
		vec3 watercolor = color
		   * pow(vec3(absorption), vec3(3.0, 0.8, 1.0))         // Water absorption color
			 * (abs(dot(lightPosition, frag.N)) * 0.8 + 0.2);        // Scatter-in factor
		float light_att = float(eyeBrightnessSmooth.y) / 240.0;

		const vec3 waterfogcolor = vec3(0.1,0.511,0.694) * 0.06;
		vec3 waterfog = (max(luma(sunLight), 0.0) * light_att) * waterfogcolor;

    color = mix(waterfog, watercolor, absorption);
  }

/* DRAWBUFFERS:5 */
  gl_FragData[0] = vec4(color, 1.0);
}
