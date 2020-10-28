#define GBUFFERS_WATER

#include "/libs/compat.glsl"
#include "/libs/encoding.glsl"

#include "/libs/color.glsl"

inout vec4 color;
inout vec3 normal;
inout vec3 tangent;
inout vec3 viewPos;
inout vec2 uv;
inout vec2 lmcoord;
inout flat float layer;
inout flat float isWater;
inout vec3 sun_I;

#ifdef VERTEX

uniform int frameCounter;

#include "/libs/taa.glsl"

attribute vec4 mc_Entity;
attribute vec4 at_tangent;

#define VECTORS
#define BUFFERS
#define CLIPPING_PLANE
#include "/libs/uniforms.glsl"
#include "/libs/transform.glsl"

void main() {
    vec4 input_pos = gl_Vertex;
    mat4 model_view_mat = gl_ModelViewMatrix;
    mat4 proj_mat = gl_ProjectionMatrix;
    mat4 mvp_mat = gl_ModelViewProjectionMatrix;

    color = gl_Color;
    uv = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * (at_tangent.xyz / at_tangent.w));
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    vec4 vpos = model_view_mat * input_pos;
    gl_Position = proj_mat * vpos;

    viewPos = vpos.xyz;

    layer = mc_Entity.x;
    isWater = mc_Entity.y;

    gl_Position.st += JitterSampleOffset(frameCounter) * invWidthHeight * gl_Position.w;

    vec3 world_sun_dir = mat3(gbufferModelViewInverse) * (shadowLightPosition * 0.01);
    vec4 sunSample = texture(gaux4, project_skybox2uv(world_sun_dir));
    sun_I = sunSample.rgb * sunSample.a;
}

#else

uniform sampler2D tex;

#define VECTORS
#define BUFFERS
#define CLIPPING_PLANE
#include "/libs/uniforms.glsl"
#include "/libs/transform.glsl"

#include "/libs/noise.glsl"
#include "/libs/bsdf.glsl"

#include "/libs/sampling.glsl"
#include "/libs/raytrace.glsl"
#include "/libs/water.glsl"

uniform int isEyeInWater;

#define WaterParallaxMapping
#define WATER_PARALLAX_QUALITY 0.7 // [0.3 0.5 0.7 1.0]

void main() {
/* DRAWBUFFERS:0 */
    vec4 c = vec4(0.0);

    ivec2 iuv = ivec2(gl_FragCoord.st);

    float skyLight = max(0.0, exp2(-(0.96875 - lmcoord.y) * 4.0) - 0.25);

    vec3 V;
    vec3 surfaceNormal = normal;
    vec3 surfaceVPos = viewPos;
    vec3 wpos = view2world(viewPos.xyz);

    vec3 albedo = vec3(1.0);

    float s, ds;
    vec3 spos_cascaded = shadowProjCascaded(world2shadowProj(wpos), s, ds);
    float shadows = shadowTexSmooth(shadowtex1, spos_cascaded, ds, 0.0);

    if (isWater == 0)
    {
        c.a = 1.0;

        V = -normalize(viewPos);

        float land_depth = texelFetch(depthtex1, iuv, 0).r;
        vec3 land_vpos = proj2view(getProjPos(iuv, land_depth));

        vec3 bitangent = cross(tangent, normal);

        float lod_wavelength = max(length(dFdx(wpos)), length(dFdy(wpos)));
        float waterLod = clamp(0.5 / lod_wavelength, 0.1, 1.0);

        vec3 wwpos = wpos + cameraPosition;

        vec3 world_bitangent = mat3(gbufferModelViewInverse) * bitangent;
        vec3 world_tangent = mat3(gbufferModelViewInverse) * tangent;
        vec3 world_normal = mat3(gbufferModelViewInverse) * normal;
        
#ifdef WaterParallaxMapping
        if (abs(world_normal.y) > 0.9)
        {
            wwpos = WaterParallax(wwpos, waterLod * WATER_PARALLAX_QUALITY, wpos);
            surfaceVPos = world2view(wwpos - cameraPosition);
        }
#endif

        if (land_vpos.z > surfaceVPos.z) discard;

        vec3 waterWNormal = get_water_normal(wwpos, waterLod, world_normal, world_tangent, world_bitangent);
        if (isEyeInWater == 1) waterWNormal = -waterWNormal;
        surfaceNormal = mat3(gbufferModelView) * waterWNormal;

        vec3 refractDir = refract(V, surfaceNormal, isEyeInWater == 1 ? 1.2 : 1.0 / 1.2);

        float waterDepth = abs(land_vpos.z - surfaceVPos.z);

        float foam = getpeaks(wwpos, 1.0, 2, 4) * (getpeaks(wwpos, 1.0, 0, 2) * 0.7 + 0.3);
        foam = max(foam, 0.3 * (1.0 - smoothstep(0.1, 0.7, waterDepth)) * (1.0 + getwave(wwpos * 10.0, 1.0, 2) / SEA_HEIGHT * 0.8));
        foam *= max(0.0, dot(surfaceNormal, shadowLightPosition * 0.01));

        if (refractDir == vec3(0.0))
        {
            c.rgb = vec3(0.0);
        }
        else
        {
            vec3 refractedVpos = surfaceVPos + refractDir * clamp(waterDepth, 0.0, 0.5);
            vec3 projPos = view2proj(refractedVpos);
            vec2 projUV = projPos.st * 0.5 + 0.5;

            vec3 new_land_vpos = proj2view(getProjPos(projUV, texture(depthtex1, projUV).r));

            if (new_land_vpos.z < surfaceVPos.z)
            {
                c.rgb = texture(gaux2, projUV, 0).rgb;
                land_vpos = new_land_vpos;
            }
            else
            {
                c.rgb = texelFetch(gaux2, iuv, 0).rgb;
            }
        }

        if (isEyeInWater != 1)
        {
            float absorption = min(1.0, waterDepth * 0.03125);
            absorption = 2.0 / (absorption + 1.0) - 1.0;
            absorption *= absorption;
            vec3 transmitance = pow(vec3(absorption), vec3(3.0, 0.8, 1.0));
            c.rgb *= transmitance;
        }

        V = -normalize(surfaceVPos.xyz);

        c.rgb += sun_I * (0.2 + shadows * 0.8) * lmcoord.y * vec3(foam) * 0.2;
    }
    else
    {
        vec4 texCol = texture(tex, uv).rgba;
        albedo = fromGamma(color.rgb * texCol.rgb);

        V = -normalize(viewPos.xyz);
        float fresnel = pow5(1.0 - max(dot(normal, V), 0.0));

        c.a = clamp(fresnel * (1.0 - texCol.a) + texCol.a, 0.0, 1.0);
    }

    vec3 mirrorDir = reflect(-V, surfaceNormal);

    vec3 dir = mat3(gbufferModelViewInverse) * mirrorDir;
    vec3 sky;

    float stride = max(2.0, viewHeight / 480.0);
    int lod = 0;
    ivec2 reflected = raytrace(surfaceVPos.xyz, vec2(iuv), mirrorDir, stride, 1.3, -surfaceVPos.z * 0.3, 0, lod, true);

    if (reflected != ivec2(-1))
    {
        sky = texelFetch(gaux2, reflected, 0).rgb * lmcoord.y;
    }
    else
    {
        sky = isEyeInWater == 1 ? vec3(0.0) : texture(gaux4, project_skybox2uv(dir)).rgb * skyLight;
    }

    if (isWater == 0)
    {
        sky *= fresnelSchlick(dot(mirrorDir, surfaceNormal), vec3(0.02));
    }

    if (isWater != 0 || isEyeInWater == 0)
    {
        c.rgb += specular_brdf_ggx_oren_schlick(sun_I * shadows, 0.2, vec3(0.02), shadowLightPosition * 0.01, surfaceNormal, V) * clamp(1.0 / c.a, 1.0, 10.0);
    }

    c.rgb += sky * albedo;

    gl_FragData[0] = c;
}

#endif