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

vec3 fxaa(sampler2D tex, vec2 fragCoord, vec2 uv, vec2 resolution) {
    vec3 color;
    vec2 inverseVP = vec2(1.0 / resolution.x, 1.0 / resolution.y);
    #ifdef HIGH_LEVEL_SHADER
    ivec2 iuv = ivec2(uv * resolution);
    vec3 rgbNW = texelFetch2DOffset(tex, iuv, 0, ivec2(-1, 0)).rgb;
    vec3 rgbNE = texelFetch2DOffset(tex, iuv, 0, ivec2( 0, 0)).rgb;
    vec3 rgbSW = texelFetch2DOffset(tex, iuv, 0, ivec2(-1,-1)).rgb;
    vec3 rgbSE = texelFetch2DOffset(tex, iuv, 0, ivec2( 0,-1)).rgb;
    vec3 rgbM = texelFetch2D(tex, iuv, 0).rgb;
    #else
    vec3 rgbNW = texture2D(tex, fragCoord + vec2(-1., 0.) * inverseVP).rgb;
    vec3 rgbNE = texture2D(tex, fragCoord + vec2( 0., 0.) * inverseVP).rgb;
    vec3 rgbSW = texture2D(tex, fragCoord + vec2(-1.,-1.) * inverseVP).rgb;
    vec3 rgbSE = texture2D(tex, fragCoord + vec2( 0.,-1.) * inverseVP).rgb;
    vec3 rgbM = texture2D(tex, fragCoord).rgb;
    #endif

    float lumaNW = luma(rgbNW);
    float lumaNE = luma(rgbNE);
    float lumaSW = luma(rgbSW);
    float lumaSE = luma(rgbSE);
    float lumaM  = luma(rgbM);
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    
    vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
                          (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);
    
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
              max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
              dir * rcpDirMin)) * inverseVP;
    
    vec3 rgbA = 0.5 * (
        texture2D(tex, uv + dir * (1.0 / 3.0 - 0.5)).rgb +
        texture2D(tex, uv + dir * (2.0 / 3.0 - 0.5)).rgb);
    vec3 rgbB = rgbA * 0.5 + 0.25 * (
        texture2D(tex, uv + dir * -0.5).rgb +
        texture2D(tex, uv + dir * 0.5).rgb);

    float lumaB = luma(rgbB);
    return ((lumaB < lumaMin) || (lumaB > lumaMax)) ? rgbA : rgbB;
}