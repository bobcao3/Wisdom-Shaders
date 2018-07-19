#ifndef _INCLUDE_VECTORS
#define _INCLUDE_VECTORS

vec4 fetch_vpos (vec2 uv, float z) {
	vec4 v = gbufferProjectionInverse * vec4(fma(vec3(uv, z), vec3(2.0f), vec3(-1.0)), 1.0);
	v /= v.w;

	return v;
}

vec4 fetch_vpos (vec2 uv, sampler2D sam) {
	return fetch_vpos(uv, texture2D(sam, uv).x);
}

float linearizeDepth(float depth) { return (2.0 * near) / (far + near - depth * (far - near));}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(fma(p.z, 0.5f, 0.5f));
}

float distanceSquared(vec3 a, vec3 b) {
	a -= b;
	return dot(a, a);
}

vec2 screen_project (vec3 vpos) {
	vec4 p = mat4(gbufferProjection) * vec4(vpos, 1.0f);
	p /= p.w;
	if(abs(p.z) > 1.0)
		return vec2(-1.0);
	return fma(p.st, vec2(0.5f), vec2(0.5f));
}

#define Positive(a) clamp(a, 0.0, 1.0)

const float PI = 3.14159f;

vec3 project_uv2skybox(vec2 uv) {
	vec2 rad = uv * 2.0 * PI;
    rad.y -= PI * 0.5;
    return normalize(vec3(cos(rad.x) * cos(rad.y), sin(rad.y), sin(rad.x) * cos(rad.y)));
}

vec2 project_skybox2uv(vec3 nwpos) {
	vec2 rad = vec2(atan(nwpos.z, nwpos.x), asin(nwpos.y));
	rad += vec2(step(0.0, -rad.x) * (PI * 2.0), PI * 0.5);
	rad *= 0.5 / PI;
	return rad;
}

#endif