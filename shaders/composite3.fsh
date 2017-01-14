#version 130
#pragma optimize(on)

const bool compositeMipmapEnabled = true;

uniform sampler2D depthtex0;
uniform sampler2D gcolor;
uniform sampler2D gdepth;
uniform sampler2D gnormal;
uniform sampler2D composite;
uniform sampler2D gaux1;
uniform sampler2D gaux2;
uniform sampler2D gaux3;
uniform sampler2D noisetex;
uniform sampler2D shadowtex0;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelView;

uniform vec3 shadowLightPosition;
vec3 lightPosition = normalize(shadowLightPosition);
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform float viewWidth;
uniform float viewHeight;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform float wetness;

uniform bool isEyeInWater;

in vec2 texcoord;
in vec3 worldLightPos;
in vec3 suncolor;

vec3 normalDecode(in vec2 enc) {
	vec4 nn = vec4(2.0 * enc - 1.0, 1.0, -1.0);
	float l = dot(nn.xyz,-nn.xyw);
	nn.z = l;
	nn.xy *= sqrt(l);
	return nn.xyz * 2.0 + vec3(0.0, 0.0, -1.0);
}

const float PI = 3.14159;
const float hPI = PI / 2;

#define fogBaseDistance 128.0 // [64.0 128.0 256.0 512.0]

float dFar = 1.0 / far;

struct Mask {
	float flag;

	bool is_valid;
	bool is_water;
	bool is_trans;
	bool is_glass;
};

struct Material {
	vec4 vpos;
	lowp vec3 normal;
	vec3 wpos;
	lowp vec3 wnormal;
	float cdepth;
	float cdepthN;
};

struct Global {
	vec4 normaltex;
	vec4 mcdata;
} g;

Material frag;
Mask frag_mask;

vec3 color = texture(composite, texcoord).rgb;

void init_struct() {
	frag.vpos = vec4(texture(gdepth, texcoord).xyz, 1.0);
	frag.wpos = (gbufferModelViewInverse * frag.vpos).xyz;
	frag.normal = normalDecode(g.normaltex.xy);
	frag.wnormal = mat3(gbufferModelViewInverse) * frag.normal;
	frag.cdepth = length(frag.wpos);
	frag.cdepthN = frag.cdepth * dFar;
	frag_mask.flag = g.mcdata.a;
	frag_mask.is_valid = (frag_mask.flag > 0.01);
	frag_mask.is_water = (frag_mask.flag > 0.71f && frag_mask.flag < 0.79f);
	frag_mask.is_glass = (frag_mask.flag > 0.93);
	frag_mask.is_trans = frag_mask.is_water || frag_mask.is_glass;
}

#define SHADOW_MAP_BIAS 0.9
float fast_shadow_map(in vec3 wpos) {
	if (frag.cdepthN > 0.9f)
		return 0.0f;
	float shade = 0.0;
	vec4 shadowposition = shadowModelView * vec4(wpos, 1.0f);
	shadowposition = shadowProjection * shadowposition;
	float distb = sqrt(shadowposition.x * shadowposition.x + shadowposition.y * shadowposition.y);
	float distortFactor = (1.0f - SHADOW_MAP_BIAS) + distb * SHADOW_MAP_BIAS;
	shadowposition.xy /= distortFactor;
	shadowposition /= shadowposition.w;
	shadowposition = shadowposition * 0.5f + 0.5f;
	float shadowDepth = texture(shadowtex0, shadowposition.st).r;
	shade = float(shadowDepth + 0.0005f + frag.cdepthN * 0.05 < shadowposition.z);
	/*
	float edgeX = abs(shadowposition.x) - 0.9f;
	float edgeY = abs(shadowposition.y) - 0.9f;
	shade -= max(0.0f, edgeX * 10.0f);
	shade -= max(0.0f, edgeY * 10.0f);
	shade -= clamp((cdepthN - 0.7f) * 5.0f, 0.0f, 1.0f);
	shade = clamp(shade, 0.0f, 1.0f);*/
	return shade;
}
/*
lowp float getwave(in vec3 worldpos) {
	vec3 wpos = worldpos + frameTimeCounter * vec3(0.0, 0.4, 0.3);
	lowp float wave = 0.015 * sin(2 * PI * (frameTimeCounter*0.65 + worldpos.x /  1.0 + worldpos.z / 3.0)) - 0.02 * sin(2 * PI * (frameTimeCounter*0.4 - worldpos.x / 11.0 + worldpos.z /  5.0));
	lowp float noise = texture(noisetex, (wpos.xz * 0.18) * 0.005).r;
	noise = noise * 0.5 + texture(noisetex, (wpos.xz * 0.29) * 0.003).r;
	noise = noise + 0.1 * texture(noisetex, (wpos.xz * 0.41) * 0.01).r;
	wave += pow(noise, 2) * 0.5 - 0.5;
	float fy = fract(worldpos.y + 0.001);
	return clamp(wave, -fy, 1.0 - fy);
}*/

#define n(p) sin(texture2D(noisetex, fract(p)).x * 2.0 * PI)
float getwave(in vec3 pos){
	float speed = 0.6;

	float t = frameTimeCounter * speed;

	vec3 p = pos / (64 + 32);
	vec2 c = p.xz;

	c.x -= t / 128;

	float wave = n(c * vec2(2.00, 1.00) + vec2(c.y * 0.2, c.x * 2.0));	c /= 6;	c.x -= t / 256;	c.y += t / (128 + 64) * 1.25;
	wave += n(c * vec2(1.75, 1.50) + vec2(c.y * 0.4, c.x * 1.8));	c.y /= 4; c.x /= 2; c.xy -= t / (256 - 64) * 0.5;
	wave += n(c * vec2(1.50, 2.00) + vec2(c.y * 0.8, c.x * 1.4));

	return (wave * wave) * 0.21;// + big_wave * big_wave;
}

float luma(in vec3 color) {
	return dot(color,vec3(0.2126, 0.7152, 0.0722));
}

vec3 get_water_normal(in vec3 wwpos, in vec3 displacement) {
	vec3 w1 = vec3(0.1, getwave(wwpos + vec3(0.1, 0.0, 0.0)), 0.0);
	vec3 w2 = vec3(0.0, getwave(wwpos + vec3(0.0, 0.0, 0.1)), 0.1);
	vec3 w0 = displacement;
	#define tangent w1 - w0
	#define bitangent w2 - w0
	return normalize(cross(bitangent, tangent));
}

#define PBR

#ifdef PBR

float D_GGX_TR(in vec3 N, in vec3 H, in float a) {
	float a2     = a*a;
	float NdotH  = max(dot(N, H), 0.0);
	float NdotH2 = NdotH*NdotH;

	float nom    = a2;
	float denom  = (NdotH2 * (a2 - 1.0) + 1.0);
	denom        = PI * denom * denom;

	return nom / denom;
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0, float roughness) {
  return F0 + (max(vec3(1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
}

float GeometrySchlickGGX(float NdotV, float k) {
	float nom   = NdotV;
	float denom = NdotV * (1.0 - k) + k;

	return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float k) {
	float NdotV = max(dot(N, V), 0.0);
	float NdotL = max(dot(N, L), 0.0);
	float ggx1 = GeometrySchlickGGX(NdotV, k);
	float ggx2 = GeometrySchlickGGX(NdotL, k);

	return ggx1 * ggx2;
}

#endif

#define PLANE_REFLECTION
#ifdef PLANE_REFLECTION

#define BISEARCH(SEARCHPOINT, DIRVEC, SIGN) DIRVEC *= 0.5; SEARCHPOINT+= DIRVEC * SIGN; uv = getScreenCoordByViewCoord(SEARCHPOINT); sampleDepth = linearizeDepth(textureLod(depthtex0, uv, 0.0).x); testDepth = getLinearDepthOfViewCoord(SEARCHPOINT); SIGN = sign(sampleDepth - testDepth);

float linearizeDepth(float depth) {
	return (2.0 * near) / (far + near - depth * (far - near));
}

vec2 getScreenCoordByViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	if(p.z < -1 || p.z > 1)
		return vec2(-1.0);
	p = p * 0.5f + 0.5f;
	return p.st;
}

float getLinearDepthOfViewCoord(vec3 viewCoord) {
	vec4 p = vec4(viewCoord, 1.0);
	p = gbufferProjection * p;
	p /= p.w;
	return linearizeDepth(p.z * 0.5 + 0.5);
}

vec4 waterRayTarcing(vec3 startPoint, vec3 direction, vec3 color, float metal) {
	const float stepBase = 0.025;
	vec3 testPoint = startPoint;
	direction *= stepBase;
	bool hit = false;
	vec4 hitColor = vec4(0.0);
	vec3 lastPoint = testPoint;
	for(int i = 0; i < 40; i++) {
		testPoint += direction * pow(float(i + 1), 1.46);
		vec2 uv = getScreenCoordByViewCoord(testPoint);
		if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			hit = true;
			break;
		}
		float sampleDepth = textureLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		float testDepth = getLinearDepthOfViewCoord(testPoint);
		if(sampleDepth < testDepth && testDepth - sampleDepth < (1.0 / 2048.0) * (1.0 + testDepth * 200.0 + float(i))){
			vec3 finalPoint = lastPoint;
			float _sign = 1.0;
			direction = testPoint - lastPoint;
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			BISEARCH(finalPoint, direction, _sign);
			uv = getScreenCoordByViewCoord(finalPoint);
			hitColor = vec4(textureLod(composite, uv, 0.0).rgb, 3.0 - metal * 3.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0);
			hit = true;
			break;
		}
		lastPoint = testPoint;
	}
	if(!hit) {
		vec2 uv = getScreenCoordByViewCoord(lastPoint);
		float testDepth = getLinearDepthOfViewCoord(lastPoint);
		float sampleDepth = textureLod(depthtex0, uv, 0.0).x;
		sampleDepth = linearizeDepth(sampleDepth);
		if(testDepth - sampleDepth < 0.5) {
			hitColor = vec4(textureLod(composite, uv, 0.0).rgb, 3.0 - metal * 2.0);
			hitColor.a = clamp(1.0 - pow(distance(uv, vec2(0.5))*2.0, 4.0), 0.0, 1.0) * 0.3;
		}
	}
	return hitColor;
}
#endif

#define rand(co) fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453)

#define ENHANCED_WATER

/* DRAWBUFFERS:3 */
void main() {
	g.normaltex = texture(gnormal, texcoord);
	g.mcdata = texture(gaux2, texcoord);
	init_struct();
	float shade = g.mcdata.b, fogMul = 1.0;
	vec3 fogColor;

	float is_shaded = pow(g.mcdata.g, 10);
	float wetness2 = is_shaded * wetness;
	// * (max(dot(normal, vec3(0.0, 1.0, 0.0)), 0.0) * 0.5 + 0.5);
	vec3 ambientColor = vec3(0.155, 0.16, 0.165) * (luma(suncolor) * 0.3);

	/*
	float fragdepth = texture(depthtex0, texcoord).r;
	vec4 fragvec = gbufferProjectionInverse * vec4(texcoord, fragdepth, 1.0);
	fragvec /= fragvec.w;*/

	if (frag_mask.is_valid) {
		vec4 water_vpos = vec4(texture(gaux3, texcoord).xyz, 1.0);
		vec4 ovpos = water_vpos;
		vec3 water_wpos = (gbufferModelViewInverse * water_vpos).xyz;
		vec3 water_displacement;
		if (frag_mask.is_glass) {
			frag.vpos = water_vpos;
			frag.wpos = water_wpos;
			frag.normal = normalize(cross(dFdx(water_vpos.xyz),dFdy(water_vpos.xyz)));
		}
		if (isEyeInWater || frag_mask.is_water) {
			float wave = getwave(water_wpos + cameraPosition);
			vec3 water_plain_normal = normalize(cross(dFdx(water_wpos),dFdy(water_wpos)));
			water_displacement = wave * water_plain_normal;
			vec3 water_normal = water_plain_normal;
			water_wpos += water_displacement;
			if (water_plain_normal.y > 0.7) {
				water_normal = water_plain_normal + get_water_normal(water_wpos + cameraPosition, water_displacement);
				water_normal = normalize(water_normal);
			}

			vec3 vsnormal = normalize(mat3(gbufferModelView) * water_normal);
			water_vpos = gbufferModelView * vec4(water_wpos, 1.0);
			#ifdef ENHANCED_WATER
			const float refindex = 1.02 / 1.24;
			vec4 shifted_vpos = vec4(frag.vpos.xyz + normalize(refract(normalize(frag.vpos.xyz), vsnormal, refindex)), 1.0);
			shifted_vpos = gbufferProjection * shifted_vpos;
			shifted_vpos /= shifted_vpos.w;
			shifted_vpos = shifted_vpos * 0.5f + 0.5f;
			vec2 shifted = shifted_vpos.st;
			#else
			vec2 shifted = texcoord + water_normal.xz;
			#endif

			float shifted_flag = texture(gaux2, shifted).a;

			if (shifted_flag < 0.71f || shifted_flag > 0.92f) {
				shifted = texcoord;
			}
			frag.vpos = vec4(texture(gdepth, shifted).xyz, 1.0);
			float dist_diff = isEyeInWater ? min(length(water_vpos.xyz), length(frag.vpos.xyz)) : abs(length(frag.vpos.xyz - water_vpos.xyz));
			float dist_diff_N = pow(clamp(0.0, 11.0, dist_diff) / 11.0, 0.55);

			vec3 org_color = color;
			color = texture(composite, shifted, 0.0).rgb;
			color = mix(color, texture(composite, shifted, 1.0).rgb, dist_diff_N * 0.8);
			color = mix(color, texture(composite, shifted, 2.0).rgb, dist_diff_N * 0.6);
			color = mix(color, texture(composite, shifted, 3.0).rgb, dist_diff_N * 0.4);

			color = mix(color, org_color, pow(length(shifted - vec2(0.5)) / 1.414f, 2.0));
			if (shifted.x > 1.0 || shifted.x < 0.0 || shifted.y > 1.0 || shifted.y < 0.0) {
				color *= 0.5 + pow(length(shifted - vec2(0.5)) / 1.414f, 2.0);
			}

			vec3 watercolor = skyColor * (0.35 - wetness * 0.15) * vec3(0.6, 0.85, 0.88);
			color = mix(color, watercolor, dist_diff_N);
			float sky_reflection = clamp(0.0, dot(lightPosition, vsnormal) - 0.7, 0.05) + clamp(0.0, wave - 0.1, 0.05);
			//color += skyColor * luma(suncolor) * sky_reflection * vec3(0.09, 0.18, 0.17);

			shade = fast_shadow_map(water_wpos);

			frag.wpos = water_wpos;
			frag.normal = normalize(0.05 * vsnormal + normalize(mat3(gbufferModelView) * water_plain_normal));
			//frag.vpos.xyz = ovpos.xyz;//mix(water_vpos.xyz,  0.9);
			frag.wnormal = water_normal;
		}

		frag.wpos.y -= 1.67f;
		// Preprocess Specular
		vec4 org_specular = texture(gaux1, texcoord);
		#ifdef PBR
			vec3 specular = vec3(0.0);
			specular.r = min(org_specular.g, 0.9999);
			specular.g = org_specular.r;
			specular.b = org_specular.b;
		#else
			vec3 specular = org_specular.rgb;
			specular.g = specular.g * (1.0 - specular.r);
		#endif

		if (!frag_mask.is_water) {
			vec3 cwpos = frag.wpos + cameraPosition;
			float wetness_distribution = texture(noisetex, cwpos.xz * 0.01).r + texture(noisetex, cwpos.yz  * 0.01).r;
			wetness_distribution = wetness_distribution * 0.5 + 0.8 * (texture(noisetex, cwpos.zx * 0.002).r + texture(noisetex, cwpos.yx  * 0.002).r);
			wetness_distribution *= wetness_distribution * wetness2;
			wetness_distribution *= wetness_distribution;
			wetness_distribution = clamp(wetness_distribution, 0.0, 1.0);
			specular.g = clamp(0.1, specular.g - wetness2 * 0.2, 0.9999);
			specular.g = mix(specular.g, 0.1, wetness_distribution);

			specular.r = clamp(0.00001, specular.r + wetness2 * 0.25, 0.9999);
			specular.r = mix(specular.r, 0.6, wetness_distribution);

			color *= (1.0 - 0.5 * wetness_distribution);
		}

		if (!isEyeInWater){
			// Specular definition:
			//  specular.g -> Roughness
			//  specular.r -> Metalness (Reflectness)
			//  specular.b (PBR only) -> Light emmission (Self lighting)
			#ifdef PBR
			vec3 halfwayDir = normalize(lightPosition - normalize(frag.vpos.xyz));
			float stdNormal = D_GGX_TR(frag.normal, halfwayDir, specular.g);
			float spec = max(dot(frag.normal, halfwayDir), 0.0) * stdNormal * specular.r;

			#ifdef PLANE_REFLECTION
			vec3 viewRefRay = reflect(normalize(frag.vpos.xyz), normalize(frag.normal + vec3(rand(texcoord), 0.0, rand(texcoord.yx)) * specular.g * specular.g * 0.05));
			float reflection_fresnel_mul = frag_mask.is_trans ? 3.0 : 1.5;
			float fresnel = 0.02 + 0.98 * pow(1.0 - dot(viewRefRay, frag.normal), reflection_fresnel_mul);
			if (!isEyeInWater && specular.r > 0.01) {
				vec4 reflection = waterRayTarcing(frag.vpos.xyz + frag.normal * 0.05, viewRefRay, color, specular.r);
				color += reflection.rgb * mix(color, vec3(1.0), specular.r) * (reflection.a * specular.r) * fresnel;
			}
			#endif
			/*
			specular.g = clamp(0.0001, specular.g, 0.9999);
			vec3 V = normalize(vec3(wpos - vec3(0.0, 1.67, 0.0)));
			vec3 F0 = vec3(0.01);
			F0 = mix(F0, color, specular.g);
			vec3 F = fresnelSchlickRoughness(max(dot(normal, V), 0.0), F0, specular.r);

			vec3 no = GeometrySmith(normal, V, worldLightPos, specular.r) * stdNormal * F;
			float denominator = max(0.0, 4 * max(dot(V, normal), 0.0) * max(dot(worldLightPos, normal), 0.0) + 0.001);
			vec3 brdf = no / denominator;*/

			// Sun reflect // - F * specular.g
			vec3 sunref = (0.5 * (suncolor) * spec) * (1.0 - shade);
			if (frag_mask.is_water) sunref *= 0.5;
			#else
			float shininess = 32.0f - 30.0f * specular.g;
			vec3 halfwayDir = normalize(lightPosition - normalize(vpos.xyz));
			float spec = pow(max(dot(normal, halfwayDir), 0.0), shininess) * specular.r;

			// Sun reflect
			vec3 sunref = 0.5 * suncolor * spec * (1.0 - shade);
			#endif

			color += sunref;
			//color = reflection.rgb * reflection.a;

			frag.cdepthN = min(1.0, length(max(frag.wpos, water_wpos)) / fogBaseDistance);
		}

		//color = specular;
		fogMul = (64.0 - clamp(0.0, frag.wpos.y + cameraPosition.y - 64.0, 64.0)) / 64.0;

	} else {
		frag.cdepthN = 1.0;

		vec4 viewPosition = gbufferProjectionInverse * vec4(texcoord.s * 2.0 - 1.0, texcoord.t * 2.0 - 1.0, 1.0, 1.0f);
		viewPosition /= viewPosition.w;
		vec4 worldPosition = normalize(gbufferModelViewInverse * viewPosition) * far * 2.0;
		fogMul = (64.0 - clamp(0.0, worldPosition.y + cameraPosition.y - 64.0, 64.0)) / 64.0;

		frag.wpos = worldPosition.xyz;
	}
	float sunFarScatter = max(0.0, dot(normalize(frag.wpos), worldLightPos));
	fogColor = mix(ambientColor * skyColor, suncolor * skyColor, 0.5 * sunFarScatter * sunFarScatter) * skyColor;
	float fogCoord = max(0.0, frag.cdepthN - 0.6) / 0.4;
	color = mix(color, fogColor, clamp(0.0, (fogCoord * fogCoord) * fogMul, 1.0));

	gl_FragData[0] = vec4(max(vec3(0.0), color), 1.0);
}
