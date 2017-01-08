#version 130
#pragma optimize(on)

const bool compositeMipmapEnabled = true;
uniform sampler2D composite;

in vec2 texcoord;

float luma(vec3 color) {
	return dot(color,vec3(0.2126, 0.7152, 0.0722));
}

#define BLOOM
#ifdef BLOOM
vec3 bloom() {
	vec3 bloom = vec3(0.0);//texture(composite, texcoord).rgb;
	const float sbias = 1.0 / 4.0f;
	for (int i = 1; i < 12; i++) {
		vec3 data = textureLod(composite, texcoord + vec2(0.0051, 0.0) * float(i), 2.0).rgb;
		float de = 1.0 / float(i);
		bloom += data * de;

		data = textureLod(composite, texcoord + vec2(-0.0051, 0.0) * float(i), 2.0).rgb;
		bloom += data * de;
	}
	return bloom * 0.05;
}

/* DRAWBUFFERS:0 */
void main() {
	gl_FragData[0] = vec4(bloom(), 1.0);
}
#endif
