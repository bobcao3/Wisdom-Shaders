vec3 diffuse_bsdf(in vec3 albedo) {
    return albedo;
}

float oren_nayer(in vec3 v, in vec3 l, in vec3 n, in float r) {
	float NdotL = clamp(dot(n, l), 0.0, 1.0);
	float NdotV = clamp(dot(n, v), 0.0, 1.0);

	float t = max(NdotL,NdotV);
	float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
	float c = g/t - g*t;

	float a = .285 / (r+.57) + .5;
	float b = .45 * r / (r+.09);

	return NdotL * (b * c + a);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow5(max(1.0 - cosTheta, 0.001));
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow5(1.0 - cosTheta);
}

#define GeometrySchlickGGX(NdotV, k) (NdotV / (NdotV * (1.0 - k) + k))

float GeometrySmith(float NdotV, float NdotL, float k) {
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
}

float DistributionGGX(vec3 N, vec3 H, float roughness) {
	float a      = roughness*roughness;
	float a2     = a*a;
	float NdotH  = abs(dot(N, H));

	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom;

	return a2 / denom;
}

mat3 make_coord_space(vec3 n) {
    vec3 h = n;
    if (abs(h.x) <= abs(h.y) && abs(h.x) <= abs(h.z))
        h.x = 1.0;
    else if (abs(h.y) <= abs(h.x) && abs(h.y) <= abs(h.z))
        h.y = 1.0;
    else
        h.z = 1.0;

    vec3 y = normalize(cross(h, n));
    vec3 x = normalize(cross(n, y));

    return mat3(x, y, n);
}

vec3 ImportanceSampleGGX(vec2 rand, vec3 N, vec3 wo, float roughness, out float pdf)
{
	rand = clamp(rand, vec2(0.0001), vec2(0.9999));

	roughness = clamp(roughness, 0.00001, 0.999999);

	float tanTheta = roughness * sqrt(rand.x / (1.0 - rand.x));
	float theta = clamp(atan(tanTheta), 0.0, 3.1415926 * 0.5 - 0.2);
	float phi = 2.0 * 3.1415926 * rand.y;

	vec3 h = vec3(
		sin(theta) * cos(phi),
		sin(theta) * sin(phi),
		cos(theta)
	);

	h = make_coord_space(N) * h;

	float sin_h = abs(sin(theta));
	float cos_h = abs(cos(theta));

	vec3 wi = reflect(wo, h);

	pdf = (2.0 * roughness * roughness * cos_h * sin_h) / pow2((roughness * roughness - 1.0) * cos_h * cos_h + 1.0) / (4.0 * abs(dot(wo, h)));

	return wi;
}

vec3 brdf_ggx_oren_schlick(vec3 albedo, vec3 radiance, float roughness, float metallic, float subsurface, vec3 F0, vec3 L, vec3 N, vec3 V)
{
	f16vec3 H = normalize(f16vec3(L + V));
	float16_t NDF = float16_t(DistributionGGX(N, H, roughness));
	float16_t G = float16_t(oren_nayer(V, L, N, roughness));
	f16vec3 F = f16vec3(fresnelSchlickRoughness(max(0.0006, dot(H, V)), F0, roughness));

	f16vec3 kS = F;
	f16vec3 kD = f16vec3(1.0) - kS;
	kD *= float16_t(1.0) - float16_t(metallic);
	
	float16_t NdotL = min(float16_t(1.0), max(float16_t(dot(N, L)), float16_t(subsurface)));                
	
	f16vec3 numerator    = NDF * G * F;
	float16_t denominator = float16_t(4.0) * max(float16_t(dot(N, V)), float16_t(0.005)) * max(NdotL, float16_t(0.005));
	f16vec3 specular     = numerator / denominator;  
	
	return vec3(max(vec3(0.0), (kD * albedo / float16_t(3.1415926) + specular) * radiance * NdotL));
}

vec3 diffuse_brdf_ggx_oren_schlick(vec3 albedo, vec3 radiance, float roughness, float metallic, vec3 F0, vec3 N, vec3 V)
{
	vec3 F = fresnelSchlickRoughness(max(0.0, dot(N, V)), F0, roughness);

	vec3 kS = F;
	vec3 kD = vec3(1.0) - kS;
	kD *= 1.0 - metallic;	  
	
	return kD * albedo / 3.1415926 * radiance;
}

vec3 specular_brdf_ggx_oren_schlick(vec3 radiance, float roughness, vec3 F0, vec3 L, vec3 N, vec3 V)
{
	vec3 H = normalize(L + V);
	float NDF = DistributionGGX(N, H, roughness);
	float G = oren_nayer(V, L, N, roughness);
	vec3 F = fresnelSchlickRoughness(max(0.0, dot(H, V)), F0, roughness);
	
	vec3 numerator    = NDF * G * F;
	float denominator = 4.0 * max(dot(N, V), 0.001) * max(dot(N, L), 0.001);
	vec3 specular     = numerator / denominator;  
	
	float NdotL = max(dot(N, L), 0.0);                
	return max(vec3(0.0), specular * radiance * NdotL); 
}

bool match(float a, float b)
{
	return (a > b - 0.002 && a < b + 0.002);
}

vec3 getF(float metalic, float cosTheta)
{
	if (metalic < 229.5 / 255.0)
		return vec3(1.0);

	#include "materials.glsl"

	cosTheta = max(0.01, abs(cosTheta));

	vec3 NcosTheta = 2.0 * N * cosTheta;
	float cosTheta2 = cosTheta * cosTheta;
	vec3 N2K2 = N * N + K * K;

	vec3 Rs = (N2K2 - NcosTheta + cosTheta2) / (N2K2 + NcosTheta + cosTheta2);
	vec3 Rp = (N2K2 * cosTheta2 - NcosTheta + 1.0) / (N2K2 * cosTheta2 + NcosTheta + 1.0);

	return (Rs + Rp) * 0.5;
}

vec3 getF0(vec3 albedo, float metalic)
{
	if (metalic < 229.5 / 255.0)
		return albedo * metalic;

	#include "materials.glsl"

	float cosTheta = 1.0;

	vec3 NcosTheta = 2.0 * N * cosTheta;
	float cosTheta2 = cosTheta * cosTheta;
	vec3 N2K2 = N * N + K * K;

	vec3 Rs = (N2K2 - NcosTheta + cosTheta2) / (N2K2 + NcosTheta + cosTheta2);
	vec3 Rp = (N2K2 * cosTheta2 - NcosTheta + 1.0) / (N2K2 * cosTheta2 + NcosTheta + 1.0);

	return (Rs + Rp) * 0.5;
}