#version 120

varying vec4 color;

/* RENDERTARGETS: 10 */
void main() {
	float Y = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
	float Cb = (color.rgb.b - Y) / (2.0 * (1.0 - 0.0722)) + 0.5;
	float alpha = clamp(color.a, 0.0, 1.0);
	vec3 encoded = vec3(1.0, Y, clamp(Cb, 0.0, 1.0));
	gl_FragData[0] = vec4(encoded * alpha, alpha);
}
