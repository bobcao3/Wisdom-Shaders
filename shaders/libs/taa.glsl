vec2 WeylNth(int n) {
	return fract(vec2(n * 12664745, n*9560333) / exp2(24.0));
}

vec2 JitterSampleOffset(int frameCounter) {
	return (WeylNth(int(mod(frameCounter, 16.0f))) * 2.0 - 1.0);
}