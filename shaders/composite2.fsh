#version 420 compatibility
#pragma optimize(on)

uniform sampler2D colortex0;

uniform float viewWidth;
uniform float viewHeight;

void main() {
    ivec2 iuv = ivec2(gl_FragCoord.st);

    vec3 bloom = vec3(0.0);

    if (iuv.x < viewWidth * 0.5 && iuv.y < viewHeight * 0.5)
    {
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2(-2,  0)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 2,  0)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 0,  2)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 0, -2)).rgb * 0.125;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2(-2, -2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 2,  2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2(-2,  2)).rgb * 0.0625;
        bloom += texelFetchOffset(colortex0, iuv * 2, 0, ivec2( 2, -2)).rgb * 0.0625;
        bloom += texelFetch(colortex0, iuv * 2, 0).rgb * 0.25;
    }

/* DRAWBUFFERS:1 */
    gl_FragData[0] = vec4(bloom, 1.0);
}