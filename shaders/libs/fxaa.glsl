/**
 *
 * From:
 * https://github.com/mitsuhiko/webgl-meincraft
 *
 * Refined by Cheng Cao (@bobcao3)
 * 
*/

#define FXAA_REDUCE_MIN   (1.0/ 128.0)
#define FXAA_REDUCE_MUL   (1.0 / 8.0)
#define FXAA_SPAN_MAX     8.0

f16vec3 fxaa(sampler2D tex, f16vec2 fragCoord, f16vec2 uv, f16vec2 resolution) {
    f16vec3 color;
    f16vec2 inverseVP = vec2(1.0 / resolution.x, 1.0 / resolution.y);
    f16vec3 rgbNW = texture2DOffset(tex, fragCoord, ivec2(-1, 0)).rgb;
    f16vec3 rgbNE = texture2DOffset(tex, fragCoord, ivec2( 0, 0)).rgb;
    f16vec3 rgbSW = texture2DOffset(tex, fragCoord, ivec2(-1,-1)).rgb;
    f16vec3 rgbSE = texture2DOffset(tex, fragCoord, ivec2( 0,-1)).rgb;
    f16vec3 rgbM = texture2D(tex, fragCoord).rgb;

    float16_t lumaNW = luma(rgbNW);
    float16_t lumaNE = luma(rgbNE);
    float16_t lumaSW = luma(rgbSW);
    float16_t lumaSE = luma(rgbSE);
    float16_t lumaM  = luma(rgbM);
    float16_t lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float16_t lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    
    f16vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
    float16_t dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                          (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
    
    float16_t rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
              max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
              dir * rcpDirMin)) * inverseVP;
    
    f16vec3 rgbA = 0.5 * (
        texture2D(tex, uv + dir * (1.0 / 3.0 - 0.5)).rgb +
        texture2D(tex, uv + dir * (2.0 / 3.0 - 0.5)).rgb);
    f16vec3 rgbB = rgbA * 0.5 + 0.25 * (
        texture2D(tex, uv + dir * -0.5).rgb +
        texture2D(tex, uv + dir * 0.5).rgb);

    float16_t lumaB = luma(rgbB);
    return ((lumaB < lumaMin) || (lumaB > lumaMax)) ? rgbA : rgbB;
}