#ifdef TRANSFORMATIONS
#ifndef _INCLUDE_TRANSFORMATIONS
#define _INCLUDE_TRANSFORMATIONS
uniform mat4 gbufferModelView;                  // modelview matrix after setting up the camera transformations
uniform mat4 gbufferProjection;                 // projection matrix when the gbuffers were generated
uniform mat4 shadowProjection;                  // projection matrix when the shadow map was generated
uniform mat4 shadowModelView;                   // modelview matrix when the shadow map was generated
uniform float viewHeight;
uniform float viewWidth;
#endif
#endif

#ifdef TRANSFORMATIONS_INVERSE
#ifndef _INCLUDE_TRANSFORMATIONS_INVERSE
#define _INCLUDE_TRANSFORMATIONS_INVERSE
uniform mat4 gbufferModelViewInverse;           // inverse gbufferModelView
uniform mat4 gbufferProjectionInverse;          // inverse gbufferProjection
uniform mat4 shadowProjectionInverse;           // inverse shadowProjection
uniform mat4 shadowModelViewInverse;            // inverse shadowModelView
uniform vec2 invWidthHeight;
uniform float near;
uniform float far;
#endif
#endif

#ifdef TRANSFORMATIONS_RESIDUAL
#ifndef _INCLUDE_TRANSFORMATIONS_RESIDUAL
#define _INCLUDE_TRANSFORMATIONS_RESIDUAL
uniform mat4 gbufferPreviousModelView;          // last frame gbufferModelView
uniform mat4 gbufferPreviousProjection;         // last frame gbufferProjection
#endif
#endif

#ifdef VECTORS
#ifndef _INCLUDE_VECTORS
#define _INCLUDE_VECTORS
uniform vec3 sunPosition;                       // sun position in eye space
uniform vec3 moonPosition;                      // moon position in eye space
uniform vec3 shadowLightPosition;               // shadow light (sun or moon) position in eye space
uniform vec3 upPosition;                        // direction up
uniform vec3 cameraPosition;                    // camera position in world space
uniform vec3 previousCameraPosition;            // last frame cameraPosition
uniform vec3 skyColor;
#endif
#endif

#ifdef BUFFERS
#ifndef _INCLUDE_BUFFERS
#define _INCLUDE_BUFFERS
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex1;
#ifndef GBUFFERS_WATER
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform usampler2D colortex4;
#endif
uniform sampler2D gaux2; // colortex5
uniform sampler2D gaux3; // colortex6
uniform sampler2D gaux4; // colortex7
#endif
#endif

#ifdef TIME
#ifndef _INCLUDE_TIME
#define _INCLUDE_TIME
uniform int worldTime;
uniform int moonPhase;
uniform float rainStrength;
uniform float wetness;
uniform float frameTimeCounter;
#endif
#endif