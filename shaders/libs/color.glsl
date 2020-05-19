const float gamma = 2.4;
const float invGamma = 1.0 / 2.4;

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