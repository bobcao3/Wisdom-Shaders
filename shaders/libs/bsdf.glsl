vec3 diffuse_bsdf(in vec3 albedo) {
    return albedo;
}

float oren_nayer(in vec3 v, in vec3 l, in vec3 n, in float r, in float NdotL, in float NdotV) {
	float t = max(NdotL,NdotV);
	float g = max(.0, dot(v - n * NdotV, l - n * NdotL));
	float c = g/t - g*t;

	float a = .285 / (r+.57) + .5;
	float b = .45 * r / (r+.09);

	return NdotL * (b * c + a);
}

vec3 light_PBR_fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
	return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
	return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
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
	float NdotH  = max(0.0001, dot(N, H));

	float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
	denom = PI * denom * denom + 0.0001;

	return a2 / denom;
}

vec3 pbr_get_kD(vec3 albedo, float metalic) {
	vec3 F0 = vec3(0.01);
	F0 = mix(F0, albedo, metalic);

	return max(vec3(0.0), vec3(1.0) - F0) * (1.0 - metalic);
}

bool match(float i, float c) {
	return (i > c - 0.001) && (i < c + 0.001);
}

vec3 diffuse_specular_brdf(vec3 v, vec3 l, vec3 n, vec3 albedo, float roughness, float metalic) {
	float NdotV = max(0.0001, dot(n, v));
	float NdotL = max(0.0001, dot(n, l));

	vec3 F0 = vec3(0.01);
	F0 = mix(F0, albedo, metalic);

	if (match(metalic, 230.0 / 255.0)) {
		F0 = vec3(3.0893, 2.9318, 2.7670);
	} else if (match(metalic, 231.0 / 255.0)) {
		F0 = vec3(0.18299, 0.42108, 1.3734);
	} else if (match(metalic, 255.0 / 255.0)) {
		F0 = vec3(0.02);
	}

	vec3 H = normalize(l + v);
	float NDF = DistributionGGX(n, H, roughness);
	float G = GeometrySmith(NdotV, NdotL, roughness);
	vec3 F = light_PBR_fresnelSchlickRoughness(max(0.0001, dot(H, v)), F0, roughness);

	vec3 nominator = NDF * G * F;
	float denominator = (4 * NdotV * NdotL) + 0.01;
	vec3 specular = nominator / denominator;

	vec3 kD = max(vec3(0.0), vec3(1.0) - F) * (1.0 - metalic);

	return kD * albedo + specular;
}

vec3 pbr_brdf(vec3 v, vec3 l, vec3 n, vec3 albedo, float roughness, float metalic, out vec3 kD) {
	float NdotV = max(0.0001, dot(n, v));
	float NdotL = max(0.0001, dot(n, l));

	vec3 F0 = vec3(0.01);
	F0 = mix(F0, albedo, metalic);

	if (match(metalic, 230.0 / 255.0)) {
		F0 = vec3(3.0893, 2.9318, 2.7670);
	} else if (match(metalic, 230.0 / 255.0)) {
		F0 = vec3(0.18299, 0.42108, 1.3734);
	} else if (match(metalic, 255.0 / 255.0)) {
		F0 = vec3(0.02);
	}

	vec3 H = normalize(l + v);
	float NDF = DistributionGGX(n, H, roughness);
	float G = GeometrySmith(NdotV, NdotL, roughness);
	vec3 F = light_PBR_fresnelSchlickRoughness(dot(H, v), F0, roughness);

	vec3 nominator = NDF * G * F;
	float denominator = abs(4 * NdotV * NdotL) + 0.01;
	vec3 specular = nominator / denominator;

	kD = max(vec3(0.0), vec3(1.0) - F) * (1.0 - metalic);

	return specular;
}