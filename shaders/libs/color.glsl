#ifndef _INCLUDE_COLOR
#define _INCLUDE_COLOR

const float gamma = 2.2;
const float invGamma = 1.0 / 2.2;

vec4 fromGamma(vec4 c) {
    return pow(c, vec4(gamma));
}

vec4 toGamma(vec4 c) {
    return pow(c, vec4(invGamma));
}

vec3 fromGamma(vec3 c) {
    return pow(c, vec3(gamma));
}

vec3 toGamma(vec3 c) {
    return pow(c, vec3(invGamma));
}

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 saturation(vec3 C, float s)
{
    float l = luma(C);
    C /= l;
    C = max(pow(C, vec3(1.0 + s)), vec3(0.0));
    return C * l;
}

vec3 hsv2rgb(vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 rgb2hsv(vec3 rgb) {
 	float Cmax = max(rgb.r, max(rgb.g, rgb.b));
 	float Cmin = min(rgb.r, min(rgb.g, rgb.b));
 	float delta = Cmax - Cmin;

 	vec3 hsv = vec3(0., 0., Cmax);

 	if (Cmax > Cmin) {
 		hsv.y = delta / Cmax;

 		if (rgb.r == Cmax)
 			hsv.x = (rgb.g - rgb.b) / delta;
 		else {
 			if (rgb.g == Cmax)
 				hsv.x = 2. + (rgb.b - rgb.r) / delta;
 			else
 				hsv.x = 4. + (rgb.r - rgb.g) / delta;
 		}
 		hsv.x = fract(hsv.x / 6.);
 	}
 	return hsv;
}

float cubicHermite(float t, float p0, float p1, float m0, float m1)
{
    float t3 = t * t * t;
    float t2 = t * t;

    return (2.0 * t3 - 3.0 * t2 + 1.0) * p0 + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * p1 + (t3 - t2) * m1;
}

//#define CHROMA_PRESERVED_CURVE

float lumaCurveComponent(float l, float black, float shadow, float midtone, float highlight, float white)
{
    float m0 = (shadow - black) * 4.0;
    float m1 = (midtone - black) * 2.0;
    float m2 = (highlight - shadow) * 2.0;
    float m3 = (white - midtone) * 2.0;
    float m4 = (white - highlight) * 4.0;

    if (l < 0.25)
        l = cubicHermite((l - 0.0) * 4.0, 0.0, 1.0, m0, m1) * (shadow - black) + black;
    else if (l < 0.5)
        l = cubicHermite((l - 0.25) * 4.0, 0.0, 1.0, m1, m2) * (midtone - shadow) + shadow;
    else if (l < 0.75)
        l = cubicHermite((l - 0.5) * 4.0, 0.0, 1.0, m2, m3) * (highlight - midtone) + midtone;
    else
        l = cubicHermite((l - 0.75) * 4.0, 0.0, 1.0, m3, m4) * (white - highlight) + highlight;

    return l;
}

vec3 lumaCurve(vec3 C, float black, float shadow, float midtone, float highlight, float white)
{
    black += 0.0;
    shadow += 0.25;
    midtone += 0.5;
    highlight += 0.75;
    white += 1.0;

    C = max(C, vec3(0.0));

#ifdef CHROMA_PRESERVED_CURVE
    float l = luma(C);
    C /= l;

    l = lumaCurveComponent(l, black, shadow, midtone, highlight, white);

    return C * l;
#else
    C.r = lumaCurveComponent(C.r, black, shadow, midtone, highlight, white);
    C.g = lumaCurveComponent(C.g, black, shadow, midtone, highlight, white);
    C.b = lumaCurveComponent(C.b, black, shadow, midtone, highlight, white);

    return C;
#endif
}

const mat3 ACESInputMat = mat3(
    vec3(0.59719, 0.07600, 0.02840),
    vec3(0.35458, 0.90834, 0.13383),
    vec3(0.04823, 0.01566, 0.83777)
);

// ODT_SAT => XYZ => D60_2_D65 => sRGB
const mat3 ACESOutputMat = mat3(
    vec3( 1.60475, -0.10208, -0.00327),
    vec3(-0.53108,  1.10813, -0.07276),
    vec3(-0.07367, -0.00605,  1.07602)
);

vec3 RRTAndODTFit(vec3 v) {
    vec3 a = v * (v + 0.0245786f) - 0.000090537f;
    vec3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
    return a / b;
}

vec3 ACESFitted(vec3 color) {
    color = ACESInputMat * color;

    // Apply RRT and ODT
    color = RRTAndODTFit(color);

    color = ACESOutputMat * color;

    return color;
}

#endif