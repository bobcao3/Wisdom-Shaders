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

#ifndef _INCLUDE_UNIFORM
#define _INCLUDE_UNIFORM

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform mat4 gbufferModelView;                  // modelview matrix after setting up the camera transformations
uniform mat4 gbufferModelViewInverse;           // inverse gbufferModelView
uniform mat4 gbufferPreviousModelView;          // last frame gbufferModelView
uniform mat4 gbufferProjection;                 // projection matrix when the gbuffers were generated
uniform mat4 gbufferProjectionInverse;          // inverse gbufferProjection
uniform mat4 gbufferPreviousProjection;         // last frame gbufferProjectio

uniform mat4 shadowProjection;                  // projection matrix when the shadow map was generated
uniform mat4 shadowProjectionInverse;           // inverse shadowProjection
uniform mat4 shadowModelView;                   // modelview matrix when the shadow map was generated
uniform mat4 shadowModelViewInverse;            // inverse shadowModelView

#ifndef _frameCounter
#define _frameCounter
uniform int frameCounter;
#endif
uniform float frameTimeCounter;                 // run time, seconds (resets to 0 after 3600s)
uniform float sunAngle;                         // 0.0-1.0
uniform float shadowAngle;                      // 0.0-1.0
uniform float rainStrength;                     // 0.0-1.0
uniform float aspectRatio;                      // viewWidth / viewHeight
#ifndef VIEW_WIDTH
#define VIEW_WIDTH
uniform float viewWidth;                        // viewWidth
uniform float viewHeight;                       // viewHeight
vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);
#endif
uniform float wetness;
uniform float near;                             // near viewing plane distance
uniform float far;                              // far viewing plane distance

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunPosition;                       // sun position in eye space
uniform vec3 moonPosition;                      // moon position in eye space
uniform vec3 shadowLightPosition;               // shadow light (sun or moon) position in eye space
uniform vec3 upPosition;                        // direction up
uniform vec3 cameraPosition;                    // camera position in world space
uniform vec3 previousCameraPosition;            // last frame cameraPosition

vec3 lightPosition = normalize(shadowLightPosition);

uniform int isEyeInWater;
#endif
