// #ifdef MC_GL_ARB_conservative_depth
// #extension GL_ARB_conservative_depth : enable
//
// layout (depth_less) out float gl_FragDepth;
// #endif

#ifdef UINT_BUFFER
out uvec3 fragData[1];
#endif

void fragment();

void main() {
    fragment();
}