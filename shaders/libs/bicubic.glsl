// 4x4 bicubic filter using 4 bilinear texture lookups
// See GPU Gems 2: "Fast Third-Order Texture Filtering", Sigg & Hadwiger:
// http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter20.html

// w0, w1, w2, and w3 are the four cubic B-spline basis functions
float w0(float a) {
    return (1.0/6.0)*(a*(a*(-a + 3.0) - 3.0) + 1.0);
}

float w1(float a) {
    return (1.0/6.0)*(a*a*(3.0*a - 6.0) + 4.0);
}

float w2(float a) {
    return (1.0/6.0)*(a*(a*(-3.0*a + 3.0) + 3.0) + 1.0);
}

float w3(float a) {
    return (1.0/6.0)*(a*a*a);
}

// g0 and g1 are the two amplitude functions
float g0(float a) {
    return w0(a) + w1(a);
}

float g1(float a) {
    return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a) {
    return -1.0 + w1(a) / (w0(a) + w1(a));
}

float h1(float a) {
    return 1.0 + w3(a) / (w2(a) + w3(a));
}

vec4 texture_Bicubic(sampler2D tex, vec2 uv)
{
	uv = uv * vec2(viewWidth, viewHeight) - 0.5;
	vec2 iuv = floor( uv );
	vec2 fuv = uv - iuv;

    float g0x = g0(fuv.x);
    float g1x = g1(fuv.x);
    float h0x = h0(fuv.x);
    float h1x = h1(fuv.x);
    float h0y = h0(fuv.y);
    float h1y = h1(fuv.y);

	vec2 p0 = (vec2(iuv.x + h0x, iuv.y + h0y) + 0.5) * invWidthHeight;
	vec4 t0 = texture2D(tex, p0);
	vec2 p1 = (vec2(iuv.x + h1x, iuv.y + h0y) + 0.5) * invWidthHeight;
	vec4 t1 = texture2D(tex, p1);
	vec2 p2 = (vec2(iuv.x + h0x, iuv.y + h1y) + 0.5) * invWidthHeight;
	vec4 t2 = texture2D(tex, p2);
	vec2 p3 = (vec2(iuv.x + h1x, iuv.y + h1y) + 0.5) * invWidthHeight;
	vec4 t3 = texture2D(tex, p3);

    return g0(fuv.y) * (g0x * t0  +
                        g1x * t1) +
           g1(fuv.y) * (g0x * t2  +
                        g1x * t3);
}