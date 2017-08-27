#ifndef _INCLUDE_UNIFORM
#define _INCLUDE_UNIFORM

uniform float near;
uniform float far;

uniform float viewHeight;
uniform float viewWidth;

uniform float wetness;
uniform float rainStrength;
uniform float centerDepthSmooth;

uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

uniform bool isEyeInWater;

uniform sampler2D gcolor;
uniform sampler2D colortex1;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D gaux4;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D noisetex;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform vec3 sunPosition;
uniform vec3 shadowLightPosition;
vec3 lightPosition = normalize(shadowLightPosition);
uniform vec3 upVec;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform vec3 skyColor;

vec2 pixel = 1.0f / vec2(viewWidth, viewHeight);

uniform float frameTimeCounter;

#endif
