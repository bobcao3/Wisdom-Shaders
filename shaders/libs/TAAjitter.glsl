
#ifndef _frameCounter
#define _frameCounter
uniform int frameCounter;
#endif

#ifndef VIEW_WIDTH
#define VIEW_WIDTH
uniform float viewWidth;
uniform float viewHeight;
#endif

const vec2 haltonSequenceOffsets[16] = vec2[16](vec2(-1, -1), vec2(0, -0.3333333), vec2(-0.5, 0.3333334), vec2(0.5, -0.7777778), vec2(-0.75, -0.1111111), vec2(0.25, 0.5555556), vec2(-0.25, -0.5555556), vec2(0.75, 0.1111112), vec2(-0.875, 0.7777778), vec2(0.125, -0.9259259), vec2(-0.375, -0.2592592), vec2(0.625, 0.4074074), vec2(-0.625, -0.7037037), vec2(0.375, -0.03703701), vec2(-0.125, 0.6296296), vec2(0.875, -0.4814815));
const vec2 bayerSequenceOffsets[16] = vec2[16](vec2(0, 3) / 16.0, vec2(8, 11) / 16.0, vec2(2, 1) / 16.0, vec2(10, 9) / 16.0, vec2(12, 15) / 16.0, vec2(4, 7) / 16.0, vec2(14, 13) / 16.0, vec2(6, 5) / 16.0, vec2(3, 0) / 16.0, vec2(11, 8) / 16.0, vec2(1, 2) / 16.0, vec2(9, 10) / 16.0, vec2(15, 12) / 16.0, vec2(7, 4) / 16.0, vec2(13, 14) / 16.0, vec2(5, 6) / 16.0);

inline void TemporalJitterProjPos(inout vec4 pos) {
	pos.xy += fma(bayerSequenceOffsets[frameCounter % 12], vec2(2.0), vec2(-1.0)) / vec2(viewWidth, viewHeight);
}

inline void TemporalAntiJitterProjPos(inout vec4 pos) {
	pos.xy -= fma(bayerSequenceOffsets[frameCounter % 12], vec2(2.0), vec2(-1.0)) / vec2(viewWidth, viewHeight);
}