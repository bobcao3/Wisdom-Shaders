#ifndef _INCLUDE_ANIMATION_TIME
#define _INCLUDE_ANIMATION_TIME

// Iris frameTimeCounter is real time in seconds, but wraps to zero every hour.
// Keep animation paths periodic over that same interval to avoid discontinuities.
const float ANIMATION_TIME_PERIOD = 3600.0;
const float ANIMATION_TAU = 6.28318530718;

float animationPhase(float cyclesPerPeriod) {
    return frameTimeCounter * (ANIMATION_TAU / ANIMATION_TIME_PERIOD) * cyclesPerPeriod;
}

// Integrates a velocity around an hour-long circle. Position and velocity are
// both continuous when frameTimeCounter wraps, while short-term motion matches
// the requested units-per-second velocity.
vec2 animationOffset(vec2 velocity) {
    float phase = frameTimeCounter * (ANIMATION_TAU / ANIMATION_TIME_PERIOD);
    float radius = ANIMATION_TIME_PERIOD / ANIMATION_TAU;
    float sine = sin(phase);
    float cosine = cos(phase);
    return radius * vec2(
        velocity.x * sine + velocity.y * (cosine - 1.0),
        velocity.x * (1.0 - cosine) + velocity.y * sine
    );
}

#endif
