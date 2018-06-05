float fov = atan(1./gbufferProjection[1][1]);
//float mulfov = (isEyeInWater == 1) ? gbufferProjection[1][1]*tan(fov * 0.85):1.0;

vec4 fetch_vpos (vec2 uv, float z) {
	vec4 v = gbufferProjectionInverse * vec4(fma(vec3(uv, z), vec3(2.0f), vec3(-1.0)), 1.0);
	v /= v.w;
	//v.xy *= mulfov;

	return v;
}

vec4 fetch_vpos (vec2 uv, sampler2D sam) {
	return fetch_vpos(uv, texture2D(sam, uv).x);
}

float16_t linearizeDepth(float16_t depth) { return (2.0 * near) / (far + near - depth * (far - near));}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(fma(p.z, 0.5f, 0.5f));
}

f16vec2 screen_project (vec3 vpos) {
	f16vec4 p = f16mat4(gbufferProjection) * f16vec4(vpos, 1.0f);
	p /= p.w;
	if(abs(p.z) > 1.0)
		return f16vec2(-1.0);
	return fma(p.st, vec2(0.5f), vec2(0.5f));
}

#define Positive(a) clamp(a, 0.0, 1.0)

const float PI = 3.14159f;
