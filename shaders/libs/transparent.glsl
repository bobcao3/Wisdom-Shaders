#include "compat.glsl"
#include "encoding.glsl"

#include "color.glsl"

INOUT vec4 color;
INOUT vec3 normal;
INOUT vec4 viewPos;
INOUT vec2 uv;
INOUT vec2 lmcoord;
INOUT flat float layer;
INOUT flat float isWater;

#ifdef VERTEX

uniform int frameCounter;

#include "taa.glsl"
uniform vec2 invWidthHeight;

attribute vec4 mc_Entity;

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    viewPos = model_view_mat * input_pos;
    gl_Position = proj_mat * viewPos;

    gl_FogFragCoord = length(viewPos.xyz);

    layer = mc_Entity.x;
    isWater = mc_Entity.y;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;
}

#else

uniform sampler2D tex;

#define VECTORS
#define BUFFERS
#define CLIPPING_PLANE
#include "uniforms.glsl"
#include "transform.glsl"

#include "noise.glsl"
#include "bsdf.glsl"

#include "sampling.glsl"
#include "raytrace.glsl"

void fragment() {
/* DRAWBUFFERS:0 */
    vec4 c = vec4(0.0);

    ivec2 iuv = ivec2(gl_FragCoord.st);

    float skyLight = max(0.0, exp2(-(0.96875 - lmcoord.y) * 4.0) - 0.25);

    if (isWater == 0)
    {
        c.a = 1.0;

        float land_depth = texelFetch(depthtex1, iuv, 0).r;
        vec3 land_vpos = proj2view(getProjPos(iuv, land_depth));

        float waterDepth = abs(land_vpos.z - viewPos.z);

        c.rgb = texelFetch(gaux2, iuv, 0).rgb;

        float absorption = min(1.0, waterDepth * 0.03125);
        absorption = 2.0 / (absorption + 1.0) - 1.0;
        absorption *= absorption;
        vec3 transmitance = pow(vec3(absorption), vec3(3.0, 0.8, 1.0));
        c.rgb *= transmitance;

        vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (shadowLightPosition * 0.01);
        vec3 sun_I = texture(gaux4, project_skybox2uv(world_sun_dir)).rgb;

        vec3 V = -normalize(viewPos.xyz);

        vec3 kD;
        c.rgb += sun_I * pbr_brdf(V, shadowLightPosition * 0.01, normal, vec3(1.0), 0.01, 230.0 / 255.0, kD);

        vec3 mirrorDir = reflect(-V, normal);

        vec3 dir = mat3(gbufferModelViewInverse) * mirrorDir;
        vec3 sky = texture(gaux4, project_skybox2uv(dir)).rgb * skyLight;

        float stride = max(2.0, viewHeight / 480.0);
        int lod = 0;
        ivec2 reflected = raytrace(viewPos.xyz, vec2(iuv), mirrorDir, false, stride, 1.3, -viewPos.z * 0.3, 0, lod);

        if (reflected != ivec2(-1))
        {
            sky = texelFetch(gaux2, reflected, 0).rgb;
        }

        c.rgb += fresnelSchlick(dot(mirrorDir, normal), vec3(0.02)) * sky;
    }
    else
    {
        c = color * texture(tex, uv);
        c.rgb = fromGamma(c.rgb);

        vec3 nvpos = normalize(viewPos.xyz);
        float fresnel = pow(1.0 - max(dot(normal, -nvpos), 0.0), 5.0);
        
        vec3 reflect_dir = reflect(nvpos, normal);
        vec3 dir = mat3(gbufferModelViewInverse) * reflect_dir;
        vec3 sky = texture(gaux4, project_skybox2uv(dir)).rgb;
        c.rgb += fresnel * sky * lmcoord.y;

        c.a = clamp(fresnel * 0.3 + 0.7, 0.0, 1.0);
    }

    gl_FragData[0] = c;
}

#endif