#version 130
#pragma optimize(on)

uniform sampler2D composite;
uniform sampler2D gdepth;
//uniform sampler2D gnormal;

in vec2 texcoord;

uniform float far;

vec3 wpos = texture(gdepth, texcoord).xyz;
float cdepth = length(wpos);
float dFar = 1.0 / far;
float cdepthN = cdepth * dFar;

#define saturate(x) clamp(0.0,x,1.0)

vec3 normalDecode(vec2 enc) {
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return normalize(nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0));
}

vec3 cNormal;

float blurAO(float c) {
	float a = c;
	//lowp float rcdepth = texture(depthtex0, texcoord).r * 200.0f;
	lowp float d = 0.068 / cdepthN;
	vec3 wpos = texture(gdepth, texcoord).rgb;

	for (int i = -5; i < 0; i++) {
		vec2 adj_coord = texcoord + vec2(0.0015, 0.0) * i * d;
		vec3 nwpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(composite, adj_coord).g, c, saturate(distance(nwpos, wpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	for (int i = 1; i < 6; i++) {
		vec2 adj_coord = texcoord + vec2(-0.0015, 0.0) * i * d;
		vec3 nwpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(composite, adj_coord).g, c, saturate(distance(nwpos, wpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	return a * 0.1629;
}

#define GlobalIllumination

#ifdef GlobalIllumination
uniform sampler2D gaux4;
vec3 blurGI(vec3 c) {
	vec3 a = c;
	//lowp float rcdepth = texture(depthtex0, texcoord).r * 200.0f;
	lowp float d = 0.068 / cdepthN;
	vec3 wpos = texture(gdepth, texcoord).rgb;

	for (int i = -5; i < 0; i++) {
		vec2 adj_coord = texcoord + vec2(0.0027, 0.0) * i * d;
		vec3 nwpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(gaux4, adj_coord * 0.25).rgb, c, saturate(distance(nwpos, wpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	for (int i = 1; i < 6; i++) {
		vec2 adj_coord = texcoord + vec2(-0.0027, 0.0) * i * d;
		vec3 nwpos = texture(gdepth, adj_coord).rgb;
		a += mix(texture(gaux4, adj_coord * 0.25).rgb, c, saturate(distance(nwpos, wpos))) * 0.2 * (6.0 - abs(float(i)));
	}

	return a * 0.1629;
}
#endif

void main() {
	vec4 ctex = texture(composite, texcoord);
	//cNormal = normalDecode(texture(gnormal, texcoord).rg);

	if (ctex.r > 0.21) {
		ctex.g = blurAO(ctex.g);
	}

/* DRAWBUFFERS:37 */
	gl_FragData[0] = ctex;
	#ifdef GlobalIllumination
	gl_FragData[1] = vec4(blurGI(texture(gaux4, texcoord * 0.25).rgb), 1.0);
	#endif
}
