#version 130
#pragma optimize(on)

const bool compositeMipmapEnabled = true;
uniform sampler2D composite;

in vec2 texcoord;

#define BLOOM
#ifdef BLOOM
vec3 bloom() {
	vec3 bloom = vec3(0.0);
	const float sbias = 1.0 / 4.0f;
	for (int i = 1; i < 7; i++) {
		vec3 data = textureLod(composite, texcoord + vec2(0.0061, 0.0) * float(i), 2.0).rgb;
		float de = 1.0 / float(i);
		bloom += data * de;

		data = textureLod(composite, texcoord + vec2(-0.0061, 0.0) * float(i), 2.0).rgb;
		bloom += data * de;
	}
	return bloom * 0.05;
}
#endif

//#define SSEDAA
#ifdef SSEDAA
uniform float viewWidth;
uniform float viewHeight;
uniform sampler2D depthtex0;
uniform sampler2D gdepth;
uniform float far;

ivec2 px = ivec2(texcoord * vec2(viewWidth, viewHeight));

bool detect_edge(in ivec2 ifpx) {
	float depth0 = texelFetch(depthtex0, ifpx, 0).r;
	float depth1 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,1)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,2)).r * 0.1;
	float depth2 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,-1)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(0,-2)).r * 0.1;
	float depth3 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(1,0)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(2,0)).r * 0.1;
	float depth4 = texelFetchOffset(depthtex0, ifpx, 0, ivec2(-1,0)).r * 0.9 + texelFetchOffset(depthtex0, ifpx, 0, ivec2(-2,0)).r * 0.1;

	float edge0 = 0.0;
	edge0 += float(depth0 > depth1);
	edge0 -= float(depth0 < depth1);
	float edge1 = 0.0;
	edge1 += float(depth0 > depth2);
	edge1 -= float(depth0 < depth2);
	float edge2 = 0.0;
	edge2 += float(depth0 > depth3);
	edge2 -= float(depth0 < depth3);
	float edge3 = 0.0;
	edge3 += float(depth0 > depth4);
	edge3 -= float(depth0 < depth4);

	bool isedge = abs(edge0 + edge1 + edge2 + edge3) > 1.43;

	return isedge;
}

vec4 EDAA() {
	float ldepth = 1.0 - length(texelFetch(gdepth, px, 0)) / far;

	vec4 orgcolor = texelFetch(composite, px, 0);
	bool edge0 = detect_edge(px);
	bool edge1 = detect_edge(px + ivec2(1,0));
	bool edge2 = detect_edge(px + ivec2(-1,0));
	bool edge3 = detect_edge(px + ivec2(0,1));
	bool edge4 = detect_edge(px + ivec2(0,-1));

	vec4 color = orgcolor;
	float bias = 0.1 * ldepth;
	if (edge1 && edge3) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(1,0)), bias);
	}
	if (edge2 && edge4) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,-1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(-1,0)), bias);
	}
	if (edge1 && edge4) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,-1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(1,0)), bias);
	}
	if (edge2 && edge3) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,1)), bias);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(-1,0)), bias);
	}
	if (edge0) {
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,1)), bias * 2.0);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(0,-1)), bias * 2.0);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(1,0)), bias * 2.0);
		color = mix(color, texelFetchOffset(composite, px, 0, ivec2(-1,0)), bias * 2.0);
	}

	return color;
}

#endif

/* DRAWBUFFERS:03 */
void main() {
	#ifdef BLOOM
	gl_FragData[0] = vec4(bloom(), 1.0);
	#endif

	#ifdef SSEDAA
	gl_FragData[1] = EDAA();
	#else
	gl_FragData[1] = texture(composite, texcoord);
	#endif
}
