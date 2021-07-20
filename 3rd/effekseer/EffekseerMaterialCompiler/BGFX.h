
#pragma once

#include <iostream>
#undef min

namespace Effekseer
{
namespace BGFX
{

// static const char* material_common_define_450 = R"(
// #version 450
// #define LAYOUT(ind) layout(location = ind)
// #define lowp
// #define mediump
// #define highp
// #define IN in
// #define OUT out
// #define CENTROID centroid
// 
// )";
// 
// static const char* material_common_define_not_450 = R"(
// #define LAYOUT(ind) 
// )";

static const char* material_common_define =
	R"(
#define MOD mod
#define FRAC fract
#define LERP mix

//float atan2(in float y, in float x) {
//    return x == 0.0 ? sign(y)* 3.141592 / 2.0 : atan(y, x);
//}

)";

static const char* material_common_vs_define = R"()"

											   R"(


// Dummy
float CalcDepthFade(vec2 screenUV, float meshZ, float softParticleParam) { return 1.0; }

)";

static const char* material_common_vs_define_450 = R"()"

												   R"(
#define TEX2D texture2DLod

)";

static const char* material_common_fs_define_450 = R"()"

												   R"(

#define TEX2D texture2D

)";

static const char g_material_model_vs_src_pre[] = R"($input a_position, a_normal, a_bitangent, a_tangent, a_texcoord0, a_color0
$output v_VColor, v_UV1, v_UV2, v_WorldN_PX, v_WorldB_PY, v_WorldT_PZ, v_PosP, v_CustomData1, v_CustomData2
)";
// 	R"(
// 
// LAYOUT(0) IN vec4 a_Position;
// LAYOUT(1) IN vec3 a_Normal;
// LAYOUT(2) IN vec3 a_Binormal;
// LAYOUT(3) IN vec3 a_Tangent;
// LAYOUT(4) IN vec2 a_TexCoord;
// LAYOUT(5) IN vec4 a_Color;
// )"
// 	R"(
// 
// LAYOUT(0) CENTROID OUT lowp vec4 v_VColor;
// LAYOUT(1) CENTROID OUT mediump vec2 v_UV1;
// LAYOUT(2) CENTROID OUT mediump vec2 v_UV2;
// LAYOUT(3) OUT mediump vec4 v_WorldN_PX;
// LAYOUT(4) OUT mediump vec4 v_WorldB_PY;
// LAYOUT(5) OUT mediump vec4 v_WorldT_PZ;
// LAYOUT(6) OUT mediump vec4 v_PosP;
// //$C_OUT1$
// //$C_OUT2$
// )";

static const char g_material_model_vs_src_pre_uniform[] =

	R"(
uniform mat4 ProjectionMatrix;

#ifdef EFK__INSTANCING_DISABLED__

uniform mat4 ModelMatrix;
uniform vec4 UVOffset;
uniform vec4 ModelColor;

#else

uniform mat4 ModelMatrix[_INSTANCE_COUNT_];
uniform vec4 UVOffset[_INSTANCE_COUNT_];
uniform vec4 ModelColor[_INSTANCE_COUNT_];

#endif

uniform vec4 mUVInversed;
uniform vec4 vs_predefined_uniform;
uniform vec4 vs_cameraPosition;
)";

static const char g_material_model_vs_src_suf1[] =
	R"(

vec2 GetUV(vec2 uv)
{
	uv.y = mUVInversed.x + mUVInversed.y * uv.y;
	return uv;
}

vec2 GetUVBack(vec2 uv)
{
	uv.y = mUVInversed.z + mUVInversed.w * uv.y;
	return uv;
}


void main()
{
#ifdef EFK__INSTANCING_DISABLED__
	mat4 modelMatrix = ModelMatrix;
	vec4 uvOffset = UVOffset;
	vec4 modelColor = ModelColor * a_color0;
#else
	mat4 modelMatrix = ModelMatrix[int(gl_InstanceID)];
	vec4 uvOffset = UVOffset[int(gl_InstanceID)];
	vec4 modelColor = ModelColor[int(gl_InstanceID)] * a_color0;
#endif

	vec3 worldPos = mul(modelMatrix, vec4(a_position, 1.0)).xyz;
	mat3 modelMatRot = mat3(modelMatrix[0].xyz, modelMatrix[1].xyz, modelMatrix[2].xyz);
	vec3 worldNormal = normalize(mul(modelMatRot, a_normal));
	vec3 worldBinormal = normalize(mul(modelMatRot, a_bitangent));
	vec3 worldTangent = normalize(mul(modelMatRot, a_tangent));
	vec3 objectScale = vec3(1.0, 1.0, 1.0);

	// Calculate ObjectScale
	objectScale.x = length(mul(modelMatRot, vec3(1.0, 0.0, 0.0)));
	objectScale.y = length(mul(modelMatRot, vec3(0.0, 1.0, 0.0)));
	objectScale.z = length(mul(modelMatRot, vec3(0.0, 0.0, 1.0)));

	// UV
	vec2 uv1 = a_texcoord0.xy * uvOffset.zw + uvOffset.xy;
	vec2 uv2 = a_texcoord0.xy;

	//uv1.y = mUVInversed.x + mUVInversed.y * uv1.y;
	//uv1.y = mUVInversed.x + mUVInversed.y * uv1.y;

	vec3 pixelNormalDir = worldNormal;
	
	vec4 vcolor = modelColor;

	// Dummy
	vec2 screenUV = vec2(0.0, 0.0);
	float meshZ = 0.0;

)";

static const char g_material_model_vs_src_suf2[] =
	R"(
	worldPos = worldPos + worldPositionOffset;

	v_WorldN_PX.w = worldPos.x;
	v_WorldB_PY.w = worldPos.y;
	v_WorldT_PZ.w = worldPos.z;
	v_WorldN_PX.xyz = worldNormal;
	v_WorldB_PY.xyz = worldBinormal;
	v_WorldT_PZ.xyz = worldTangent;
	v_UV1 = uv1;
	v_UV2 = uv2;
	v_VColor = vcolor;
	gl_Position = mul(ProjectionMatrix, vec4(worldPos, 1.0));
//	v_ScreenUV.xy = gl_Position.xy / gl_Position.w;
//	v_ScreenUV.xy = vec2(v_ScreenUV.x + 1.0, v_ScreenUV.y + 1.0) * 0.5;

	v_PosP = gl_Position;

	#ifdef _Y_INVERTED_
	gl_Position.y = - gl_Position.y;
	#endif
}
)";

static const char g_material_sprite_vs_src_pre_simple[] =R"($input a_position, a_color0, a_texcoord0
$output v_VColor, v_UV1, v_UV2, v_WorldN_PX, v_WorldB_PY, v_WorldT_PZ, v_PosP
)";
// 	R"(
// 
// LAYOUT(0) IN vec4 atPosition;
// LAYOUT(1) IN vec4 atColor;
// LAYOUT(2) IN vec4 atTexCoord;
// )"
// 
// 	R"(
// LAYOUT(0) CENTROID OUT lowp vec4 v_VColor;
// LAYOUT(1) CENTROID OUT mediump vec2 v_UV1;
// LAYOUT(2) CENTROID OUT mediump vec2 v_UV2;
// LAYOUT(3) OUT mediump vec4 v_WorldN_PX;
// LAYOUT(4) OUT mediump vec4 v_WorldB_PY;
// LAYOUT(5) OUT mediump vec4 v_WorldT_PZ;
// LAYOUT(6) OUT mediump vec4 v_PosP;
// )";

static const char g_material_sprite_vs_src_pre_simple_uniform[] =
	R"(
uniform mat4 uMatCamera;
uniform mat4 uMatProjection;
uniform vec4 mUVInversed;
uniform vec4 vs_predefined_uniform;
uniform vec4 vs_cameraPosition;

)";

static const char g_material_sprite_vs_src_pre[] = R"($input a_position, a_color0, a_normal, a_tangent, a_texcoord0, a_texcoord1, a_texcoord2, a_texcoord3
$output v_VColor, v_UV1, v_UV2, v_WorldN_PX, v_WorldB_PY, v_WorldT_PZ, v_PosP, v_CustomData1, v_CustomData2
)";
// 	R"(
// 
// LAYOUT(0) IN vec4 atPosition;
// LAYOUT(1) IN vec4 atColor;
// LAYOUT(2) IN vec3 atNormal;
// LAYOUT(3) IN vec3 atTangent;
// LAYOUT(4) IN vec2 atTexCoord;
// LAYOUT(5) IN vec2 atTexCoord2;
// //$C_IN1$
// //$C_IN2$
// )"
// 
// 	R"(
// LAYOUT(0) CENTROID OUT lowp vec4 v_VColor;
// LAYOUT(1) CENTROID OUT mediump vec2 v_UV1;
// LAYOUT(2) CENTROID OUT mediump vec2 v_UV2;
// LAYOUT(3) OUT mediump vec4 v_WorldN_PX;
// LAYOUT(4) OUT mediump vec4 v_WorldB_PY;
// LAYOUT(5) OUT mediump vec4 v_WorldT_PZ;
// LAYOUT(6) OUT mediump vec4 v_PosP;
// //$C_OUT1$
// //$C_OUT2$
// )";

static const char g_material_sprite_vs_src_pre_uniform[] =

	R"(
uniform mat4 uMatCamera;
uniform mat4 uMatProjection;
uniform vec4 mUVInversed;
uniform vec4 vs_predefined_uniform;
uniform vec4 vs_cameraPosition;

)";

static const char g_material_sprite_vs_src_suf1_simple[] =

	R"(

vec2 GetUV(vec2 uv)
{
	uv.y = mUVInversed.x + mUVInversed.y * uv.y;
	return uv;
}

vec2 GetUVBack(vec2 uv)
{
	uv.y = mUVInversed.z + mUVInversed.w * uv.y;
	return uv;
}

void main() {
	vec3 worldPos = a_position.xyz;
	vec3 objectScale = vec3(1.0, 1.0, 1.0);

	// Dummy
	vec2 screenUV = vec2(0.0, 0.0);
	float meshZ = 0.0;

	// UV
	vec2 uv1 = a_texcoord0.xy;
	//uv1.y = mUVInversed.x + mUVInversed.y * uv1.y;
	vec2 uv2 = uv1;

	// NBT
	vec3 worldNormal = vec3(0.0, 0.0, 0.0);
	vec3 worldBinormal = vec3(0.0, 0.0, 0.0);
	vec3 worldTangent = vec3(0.0, 0.0, 0.0);
	v_WorldN_PX.xyz = worldNormal;
	v_WorldB_PY.xyz = worldBinormal;
	v_WorldT_PZ.xyz = worldTangent;

	vec3 pixelNormalDir = worldNormal;
	vec4 vcolor = a_color0;
)";

static const char g_material_sprite_vs_src_suf1[] =

	R"(

vec2 GetUV(vec2 uv)
{
	uv.y = mUVInversed.x + mUVInversed.y * uv.y;
	return uv;
}

vec2 GetUVBack(vec2 uv)
{
	uv.y = mUVInversed.z + mUVInversed.w * uv.y;
	return uv;
}

void main() {
	vec3 worldPos = a_position.xyz;
	vec3 objectScale = vec3(1.0, 1.0, 1.0);

	// Dummy
	vec2 screenUV = vec2(0.0, 0.0);
	float meshZ = 0.0;

	// UV
	vec2 uv1 = a_texcoord0.xy;
	//uv1.y = mUVInversed.x + mUVInversed.y * uv1.y;
	vec2 uv2 = a_texcoord1.xy;
	//uv2.y = mUVInversed.x + mUVInversed.y * uv2.y;

	// NBT
	vec3 worldNormal = (a_normal - vec3(0.5, 0.5, 0.5)) * 2.0;
	vec3 worldTangent = (a_tangent - vec3(0.5, 0.5, 0.5)) * 2.0;
	vec3 worldBinormal = cross(worldNormal, worldTangent);

	v_WorldN_PX.xyz = worldNormal;
	v_WorldB_PY.xyz = worldBinormal;
	v_WorldT_PZ.xyz = worldTangent;
	vec3 pixelNormalDir = worldNormal;
	vec4 vcolor = a_color0;
)";

static const char g_material_sprite_vs_src_suf2[] =

	R"(
	worldPos = worldPos + worldPositionOffset;

	vec4 cameraPos = mul(uMatCamera, vec4(worldPos, 1.0));
	cameraPos = cameraPos / cameraPos.w;

	gl_Position = mul(uMatProjection, cameraPos);

	v_WorldN_PX.w = worldPos.x;
	v_WorldB_PY.w = worldPos.y;
	v_WorldT_PZ.w = worldPos.z;
	v_VColor = vcolor;

	v_UV1 = uv1;
	v_UV2 = uv2;
	//v_ScreenUV.xy = gl_Position.xy / gl_Position.w;
	//v_ScreenUV.xy = vec2(v_ScreenUV.x + 1.0, v_ScreenUV.y + 1.0) * 0.5;

	v_PosP = gl_Position;

	#ifdef _Y_INVERTED_
	gl_Position.y = - gl_Position.y;
	#endif
}
)";

static const char g_material_fs_src_pre[] =
R"($input v_VColor, v_UV1, v_UV2, v_WorldN_PX, v_WorldB_PY, v_WorldT_PZ, v_PosP, v_CustomData1, v_CustomData2
)";
// 	R"(
// 
// LAYOUT(0) CENTROID IN lowp vec4 v_VColor;
// LAYOUT(1) CENTROID IN mediump vec2 v_UV1;
// LAYOUT(2) CENTROID IN mediump vec2 v_UV2;
// LAYOUT(3) IN mediump vec4 v_WorldN_PX;
// LAYOUT(4) IN mediump vec4 v_WorldB_PY;
// LAYOUT(5) IN mediump vec4 v_WorldT_PZ;
// LAYOUT(6) IN mediump vec4 v_PosP;
// //$C_PIN1$
// //$C_PIN2$
// 
// )";

static const char g_material_fs_src_pre_uniform[] =
	R"(

uniform vec4 mUVInversedBack;
uniform vec4 fs_predefined_uniform;
uniform vec4 fs_cameraPosition;
uniform vec4 reconstructionParam1;
uniform vec4 reconstructionParam2;

)";

static const char g_material_fs_src_suf1[] =
	R"(

vec2 GetUV(vec2 uv)
{
	uv.y = mUVInversedBack.x + mUVInversedBack.y * uv.y;
	return uv;
}

vec2 GetUVBack(vec2 uv)
{
	uv.y = mUVInversedBack.z + mUVInversedBack.w * uv.y;
	return uv;
}

float CalcDepthFade(vec2 screenUV, float meshZ, float softParticleParam)
{
	float backgroundZ = TEX2D(efk_depth, GetUVBack(screenUV)).x;

	float distance = softParticleParam * fs_predefined_uniform.y;
	vec2 rescale = reconstructionParam1.xy;
	vec4 params = reconstructionParam2;

	vec2 zs = vec2(backgroundZ * rescale.x + rescale.y, meshZ);

	vec2 depth = (zs * params.w - params.y) / (params.x - zs * params.z);
	float dir = sign(depth.x);
	depth *= dir;
	return min(max((depth.x - depth.y) / distance, 0.0), 1.0);
}

#ifdef _MATERIAL_LIT_

const float lightScale = 3.14;

float saturate(float v)
{
	return max(min(v, 1.0), 0.0);
}

float calcD_GGX(float roughness, float dotNH)
{
	float alpha = roughness*roughness;
	float alphaSqr = alpha*alpha;
	float pi = 3.14159;
	float denom = dotNH * dotNH *(alphaSqr-1.0) + 1.0;
	return (alpha / denom) * (alpha / denom) / pi;
}

float calcF(float F0, float dotLH)
{
	float dotLH5 = pow(1.0-dotLH,5.0);
	return F0 + (1.0-F0)*(dotLH5);
}

float calcG_Schlick(float roughness, float dotNV, float dotNL)
{
	// UE4
	float k = (roughness + 1.0) * (roughness + 1.0) / 8.0;
	// float k = roughness * roughness / 2.0;

	float gV = dotNV*(1.0 - k) + k;
	float gL = dotNL*(1.0 - k) + k;

	return 1.0 / (gV * gL);
}

float calcLightingGGX(vec3 N, vec3 V, vec3 L, float roughness, float F0)
{
	vec3 H = normalize(V+L);

	float dotNL = saturate( dot(N,L) );
	float dotLH = saturate( dot(L,H) );
	float dotNH = saturate( dot(N,H) ) - 0.001;
	float dotNV = saturate( dot(N,V) ) + 0.001;

	float D = calcD_GGX(roughness, dotNH);
	float F = calcF(F0, dotLH);
	float G = calcG_Schlick(roughness, dotNV, dotNL);

	return dotNL * D * F * G / 4.0;
}

vec3 calcDirectionalLightDiffuseColor(vec3 diffuseColor, vec3 normal, vec3 lightDir, float ao)
{
	vec3 color = vec3(0.0,0.0,0.0);

	float NoL = dot(normal,lightDir);
	color.xyz = lightColor.xyz * lightScale * max(NoL,0.0) * ao / 3.14;
	color.xyz = color.xyz * diffuseColor.xyz;
	return color;
}

#endif

void main()
{
	vec2 uv1 = v_UV1;
	vec2 uv2 = v_UV2;
	vec3 worldPos = vec3(v_WorldN_PX.w, v_WorldB_PY.w, v_WorldT_PZ.w);
	vec3 worldNormal = v_WorldN_PX.xyz;
	vec3 worldTangent = v_WorldT_PZ.xyz;
	vec3 worldBinormal = v_WorldB_PY.xyz;
	vec3 pixelNormalDir = worldNormal;
	vec4 vcolor = v_VColor;
	vec3 objectScale = vec3(1.0, 1.0, 1.0);

	vec2 screenUV = v_PosP.xy / v_PosP.w;
	float meshZ =   v_PosP.z / v_PosP.w;
	screenUV.xy = vec2(screenUV.x + 1.0, screenUV.y + 1.0) * 0.5;

#ifdef _SCREEN_FLIPPED_
	screenUV.y = 1.0 - screenUV.y;
#endif
)";

static const char g_material_fs_src_suf2_lit[] =
	R"(

	vec3 viewDir = normalize(fs_cameraPosition.xyz - worldPos);
	vec3 diffuse = calcDirectionalLightDiffuseColor(baseColor, pixelNormalDir, lightDirection.xyz, ambientOcclusion);
	vec3 specular = lightColor.xyz * lightScale * calcLightingGGX(pixelNormalDir, viewDir, lightDirection.xyz, roughness, 0.9);

	vec4 Output =  vec4(metallic * specular + (1.0 - metallic) * diffuse + baseColor * lightAmbientColor.xyz * ambientOcclusion, opacity);
	Output.xyz = Output.xyz + emissive.xyz;

	if(opacityMask <= 0.0) discard;
	if(opacity <= 0.0) discard;

	FRAGCOLOR = Output;
}
)";

static const char g_material_fs_src_suf2_unlit[] =
	R"(

	if(opacityMask <= 0.0) discard;
	if(opacity <= 0.0) discard;

	FRAGCOLOR = vec4(emissive, opacity);
}
)";

static const char g_material_fs_src_suf2_refraction[] =
	R"(
	float airRefraction = 1.0;

	vec3 dir = mul(mat3(cameraMat), pixelNormalDir);
	vec2 distortUV = dir.xy * (refraction - airRefraction);

	distortUV += screenUV;
	distortUV = GetUVBack(distortUV);	

	vec4 bg = TEX2D(efk_background, distortUV);
	FRAGCOLOR = bg;

	if(opacityMask <= 0.0) discard;
	if(opacity <= 0.0) discard;
}
)";

struct ShaderData
{
	std::string CodeVS;
	std::string CodePS;
};

class ShaderGenerator
{
	bool useUniformBlock_ = false;
	bool useSet_ = false;
	int32_t textureBindingOffset_ = 0;

	std::string Replace(std::string target, std::string from_, std::string to_)
	{
		std::string::size_type Pos(target.find(from_));

		while (Pos != std::string::npos)
		{
			target.replace(Pos, from_.length(), to_);
			Pos = target.find(from_, Pos + to_.length());
		}

		return target;
	}

	std::string GetType(int32_t i)
	{
		if (i == 1)
			return "float";
		if (i == 2)
			return "vec2";
		if (i == 3)
			return "vec3";
		if (i == 4)
			return "vec4";
		if (i == 16)
			return "mat4";
		assert(0);
		return "";
	}

	std::string GetElement(int32_t i)
	{
		if (i == 1)
			return ".x";
		if (i == 2)
			return ".xy";
		if (i == 3)
			return ".xyz";
		if (i == 4)
			return ".xyzw";
		assert(0);
		return "";
	}

	void ExportUniform(std::ostringstream& maincode, int32_t type, const char* name)
	{
		maincode << "uniform " << GetType(type) << " " << name << ";" << std::endl;
	}

	void ExportTexture(std::ostringstream& maincode, const char* name, int bind, int stage)
	{
		if (useUniformBlock_)
		{
			if (useSet_)
			{
				maincode << "layout(set = " << stage << ", binding = " << (bind + textureBindingOffset_) << ") uniform sampler2D " << name
						 << ";" << std::endl;
			}
			else
			{
				maincode << "layout(binding = " << (bind + textureBindingOffset_) << ") uniform sampler2D " << name << ";" << std::endl;
			}
		}
		else
		{
			//maincode << "uniform sampler2D " << name << ";" << std::endl;
			maincode << "SAMPLER2D(" << name << ", " << bind << ");" << std::endl;
		}
	}

	void ExportHeader(std::ostringstream& maincode, MaterialFile* materialFile, int stage, bool isSprite, bool isOutputDefined, bool is450)
	{
// 		if (is450)
// 		{
// 			maincode << material_common_define_450;
// 		}
// 		else
// 		{
// 			maincode << material_common_define_not_450;
// 		}

		if (stage == 0)
		{
			if (isSprite)
			{
				if (materialFile->GetIsSimpleVertex())
				{
					maincode << g_material_sprite_vs_src_pre_simple;
				}
				else
				{
					maincode << g_material_sprite_vs_src_pre;
				}
			}
			else
			{
				maincode << g_material_model_vs_src_pre;
			}
		}
		else
		{
			maincode << g_material_fs_src_pre;
		}

		maincode << R"(#include <common.sh>
)";

        if (stage == 0)
        {
            maincode << "#define EFK__INSTANCING_DISABLED__ 1";
        }
        else if (stage == 1)
        {
            maincode << "#define FRAGCOLOR gl_FragColor";
        }

		maincode << material_common_define;

		if (stage == 0)
		{
			maincode << material_common_vs_define;
        }

		// Adhoc
		if (true/*is450*/)
		{
			if (stage == 0)
			{
				maincode << material_common_vs_define_450;
			}
			else if (stage == 1)
			{
				maincode << material_common_fs_define_450;
			}
		}

// 		if (stage == 0)
// 		{
// 			if (isSprite)
// 			{
// 				if (materialFile->GetIsSimpleVertex())
// 				{
// 					maincode << g_material_sprite_vs_src_pre_simple;
// 				}
// 				else
// 				{
// 					maincode << g_material_sprite_vs_src_pre;
// 				}
// 			}
// 			else
// 			{
// 				maincode << g_material_model_vs_src_pre;
// 			}
// 		}
// 		else
// 		{
// 			maincode << g_material_fs_src_pre;
// 		}
// 		if (isOutputDefined && stage == 1)
// 		{
// 			maincode << "layout(location = 0) out vec4 out_flagColor;" << std::endl;
// 			maincode << std::endl;
// 		}
	}

	void ExportDefaultUniform(std::ostringstream& maincode, MaterialFile* materialFile, int stage, bool isSprite)
	{
		if (stage == 0)
		{
			if (isSprite)
			{
				if (materialFile->GetIsSimpleVertex())
				{
					maincode << g_material_sprite_vs_src_pre_simple_uniform;
				}
				else
				{
					maincode << g_material_sprite_vs_src_pre_uniform;
				}
			}
			else
			{
				maincode << g_material_model_vs_src_pre_uniform;
			}
		}
		else
		{
			maincode << g_material_fs_src_pre_uniform;
		}
	}

	void ExportMain(std::ostringstream& maincode,
					MaterialFile* materialFile,
					int stage,
					bool isSprite,
					MaterialShaderType shaderType,
					const std::string& baseCode,
					bool useUniformBlock)
	{
		if (stage == 0)
		{
			if (isSprite)
			{
				if (materialFile->GetIsSimpleVertex())
				{
					maincode << g_material_sprite_vs_src_suf1_simple;
				}
				else
				{
					maincode << g_material_sprite_vs_src_suf1;
				}
			}
			else
			{
				maincode << g_material_model_vs_src_suf1;
			}

			if (materialFile->GetCustomData1Count() > 0)
			{
				if (isSprite)
				{
					maincode << GetType(materialFile->GetCustomData1Count()) + " customData1 = a_texcoord2;\n";
				}
				else
				{
					maincode << "#ifndef EFK__INSTANCING_DISABLED__" << std::endl;
					maincode << GetType(4) + " customData1 = customData1s[int(gl_InstanceID)];\n";
					maincode << "#endif" << std::endl;
				}
				maincode << "v_CustomData1 = customData1" + GetElement(materialFile->GetCustomData1Count()) + ";\n";
			}

			if (materialFile->GetCustomData2Count() > 0)
			{
				if (isSprite)
				{
					maincode << GetType(materialFile->GetCustomData2Count()) + " customData2 = a_texcoord3;\n";
				}
				else
				{
					maincode << "#ifndef EFK__INSTANCING_DISABLED__" << std::endl;
					maincode << GetType(4) + " customData2 = customData2s[int(gl_InstanceID)];\n";
					maincode << "#endif" << std::endl;
				}
				maincode << "v_CustomData2 = customData2" + GetElement(materialFile->GetCustomData2Count()) + ";\n";
			}

			maincode << baseCode;

			if (isSprite)
			{
				maincode << g_material_sprite_vs_src_suf2;
			}
			else
			{
				maincode << g_material_model_vs_src_suf2;
			}
		}
		else
		{
			maincode << g_material_fs_src_suf1;

			if (materialFile->GetCustomData1Count() > 0)
			{
				maincode << GetType(materialFile->GetCustomData1Count()) + " customData1 = v_CustomData1;\n";
			}

			if (materialFile->GetCustomData2Count() > 0)
			{
				maincode << GetType(materialFile->GetCustomData2Count()) + " customData2 = v_CustomData2;\n";
			}

			maincode << baseCode;

			if (shaderType == MaterialShaderType::Refraction || shaderType == MaterialShaderType::RefractionModel)
			{
				maincode << g_material_fs_src_suf2_refraction;
			}
			else
			{
				if (materialFile->GetShadingModel() == Effekseer::ShadingModelType::Lit)
				{
					maincode << g_material_fs_src_suf2_lit;
				}
				else if (materialFile->GetShadingModel() == Effekseer::ShadingModelType::Unlit)
				{
					maincode << g_material_fs_src_suf2_unlit;
				}
			}
		}
	}

public:
	ShaderData GenerateShader(MaterialFile* materialFile,
							  MaterialShaderType shaderType,
							  int32_t maximumTextureCount,
							  bool useUniformBlock,
							  bool isOutputDefined,
							  bool is450,
							  bool useSet,
							  int textureBindingOffset,
							  bool isYInverted,
							  bool isScreenFlipped,
							  int instanceCount)
	{
		useUniformBlock_ = useUniformBlock;
		useSet_ = useSet;
		textureBindingOffset_ = textureBindingOffset;

		bool isSprite = shaderType == MaterialShaderType::Standard || shaderType == MaterialShaderType::Refraction;
		bool isRefrection = materialFile->GetHasRefraction() &&
							(shaderType == MaterialShaderType::Refraction || shaderType == MaterialShaderType::RefractionModel);

		ShaderData shaderData;

		for (int stage = 0; stage < 2; stage++)
		{
			std::ostringstream maincode;

			ExportHeader(maincode, materialFile, stage, isSprite, isOutputDefined, is450);

			if (isYInverted)
			{
				maincode << "#define _Y_INVERTED_ 1" << std::endl;
			}

			if (isScreenFlipped)
			{
				maincode << "#define _SCREEN_FLIPPED_ 1" << std::endl;
			}

			if (stage == 0)
			{
				maincode << "#define _INSTANCE_COUNT_ " << instanceCount << std::endl;
			}

			// TODO : Replace DIRTY CODE
			if (textureBindingOffset > 0)
			{
				// Vulkan
				maincode << "#define gl_InstanceID gl_InstanceIndex" << std::endl;
			}

            int32_t actualTextureCount = std::min(maximumTextureCount, materialFile->GetTextureCount());

            for (int32_t i = 0; i < actualTextureCount; i++)
            {
                auto textureName = materialFile->GetTextureName(i);

                ExportTexture(maincode, textureName, i, stage);
            }

			ExportTexture(maincode, "efk_background", actualTextureCount + 0, stage);
            ExportTexture(maincode, "efk_depth", actualTextureCount + 1, stage);

			// Uniform block begin
			if (useUniformBlock)
			{
				if (useSet_)
				{
					if (stage == 0)
					{
						maincode << "layout(set = 0, binding = 0) uniform Block {" << std::endl;
					}
					else if (stage == 1)
					{
						maincode << "layout(set = 1, binding = 0) uniform Block {" << std::endl;
					}
				}
				else
				{
					if (stage == 0)
					{
						maincode << "layout(binding = 0) uniform Block {" << std::endl;
					}
					else if (stage == 1)
					{
						maincode << "layout(binding = 0) uniform Block {" << std::endl;
					}
				}
			}

			ExportDefaultUniform(maincode, materialFile, stage, isSprite);

			if (materialFile->GetShadingModel() == ::Effekseer::ShadingModelType::Lit && stage == 1)
			{
				ExportUniform(maincode, 4, "lightDirection");
				ExportUniform(maincode, 4, "lightColor");
				ExportUniform(maincode, 4, "lightAmbientColor");

				maincode << "#define _MATERIAL_LIT_ 1" << std::endl;
			}
			else if (materialFile->GetShadingModel() == ::Effekseer::ShadingModelType::Unlit)
			{
			}

			if (isRefrection && stage == 1)
			{
				ExportUniform(maincode, 16, "cameraMat");
			}

			if (!isSprite && stage == 0)
			{
				if (materialFile->GetCustomData1Count() > 0)
				{
					maincode << R"(

#ifdef EFK__INSTANCING_DISABLED__
uniform vec4 customData1;
#else
uniform vec4 customData1s[_INSTANCE_COUNT_];
#endif
)" << std::endl;
				}
				if (materialFile->GetCustomData2Count() > 0)
				{

					maincode << R"(

#ifdef EFK__INSTANCING_DISABLED__
uniform vec4 customData2;
#else
uniform vec4 customData2s[_INSTANCE_COUNT_];
#endif
)" << std::endl;
				}
			}

			for (int32_t i = 0; i < materialFile->GetUniformCount(); i++)
			{
				std::string orignName = materialFile->GetUniformName(i);
				if (stage == 0) {
					auto uniformName = "vs_" + orignName;
					ExportUniform(maincode, 4, uniformName.c_str());
				} else if (stage == 1) {
					auto uniformName = "fs_" + orignName;
					ExportUniform(maincode, 4, uniformName.c_str());
				}
			}

			// Uniform block end
			if (useUniformBlock)
			{
				maincode << "};" << std::endl;
			}

			auto baseCode = std::string(materialFile->GetGenericCode());
			for (int32_t i = 0; i < materialFile->GetUniformCount(); i++)
			{
				std::string orignName = materialFile->GetUniformName(i);
				std::string newName;
				if (stage == 0) {
					newName = "vs_" + orignName;
				}
				else if (stage == 1) {
					newName = "fs_" + orignName;
				}
				baseCode = Replace(baseCode, orignName, newName);
			}
			baseCode = Replace(baseCode, "$F1$", "float");
			baseCode = Replace(baseCode, "$F2$", "vec2");
			baseCode = Replace(baseCode, "$F3$", "vec3");
			baseCode = Replace(baseCode, "$F4$", "vec4");
			if (stage == 0)
			{
                baseCode = Replace(baseCode, "$TIME$", "vs_predefined_uniform.x");
                baseCode = Replace(baseCode, "$EFFECTSCALE$", "vs_predefined_uniform.y");
			}
			else if (stage == 1)
			{
                baseCode = Replace(baseCode, "$TIME$", "fs_predefined_uniform.x");
                baseCode = Replace(baseCode, "$EFFECTSCALE$", "fs_predefined_uniform.y");
			}
			baseCode = Replace(baseCode, "$UV$", "uv");
			baseCode = Replace(baseCode, "$MOD", "mod");

			// replace textures
			for (int32_t i = 0; i < actualTextureCount; i++)
			{
				auto textureIndex = materialFile->GetTextureIndex(i);
				auto textureName = std::string(materialFile->GetTextureName(i));

				std::string keyP = "$TEX_P" + std::to_string(textureIndex) + "$";
				std::string keyS = "$TEX_S" + std::to_string(textureIndex) + "$";

				if (stage == 0)
				{
					baseCode = Replace(baseCode, keyP, "TEX2D(" + textureName + ",GetUV(");
					baseCode = Replace(baseCode, keyS, "), 0.0)");
				}
				else
				{
					baseCode = Replace(baseCode, keyP, "TEX2D(" + textureName + ",GetUV(");
					baseCode = Replace(baseCode, keyS, "))");
				}
			}

			// invalid texture
			for (int32_t i = actualTextureCount; i < materialFile->GetTextureCount(); i++)
			{
				auto textureIndex = materialFile->GetTextureIndex(i);
				auto textureName = std::string(materialFile->GetTextureName(i));

				std::string keyP = "$TEX_P" + std::to_string(textureIndex) + "$";
				std::string keyS = "$TEX_S" + std::to_string(textureIndex) + "$";

				baseCode = Replace(baseCode, keyP, "vec4(");
				baseCode = Replace(baseCode, keyS, ",0.0,1.0)");
			}

			ExportMain(maincode, materialFile, stage, isSprite, shaderType, baseCode, useUniformBlock);

			if (stage == 0)
			{
				shaderData.CodeVS = maincode.str();
			}
			else
			{
				shaderData.CodePS = maincode.str();
			}
		}

		// custom data
// 		int32_t layoutOffset = 6;
// 		int32_t pvLayoutOffset = 7;
// 
// 		if (materialFile->GetCustomData1Count() > 0)
// 		{
// 			if (isSprite)
// 			{
// 				shaderData.CodeVS = Replace(shaderData.CodeVS,
// 											"//$C_IN1$",
// 											"LAYOUT(" + std::to_string(layoutOffset) + ") " + "IN " +
// 												GetType(materialFile->GetCustomData1Count()) + " atCustomData1;");
// 			}
// 			shaderData.CodeVS = Replace(shaderData.CodeVS,
// 										"//$C_OUT1$",
// 										"LAYOUT(" + std::to_string(pvLayoutOffset) + ") " + "OUT mediump " +
// 											GetType(materialFile->GetCustomData1Count()) + " v_CustomData1;");
// 			shaderData.CodePS = Replace(shaderData.CodePS,
// 										"//$C_PIN1$",
// 										"LAYOUT(" + std::to_string(pvLayoutOffset) + ") " + "IN mediump " +
// 											GetType(materialFile->GetCustomData1Count()) + " v_CustomData1;");
// 
// 			layoutOffset += 1;
// 			pvLayoutOffset += 1;
// 		}
// 
// 		if (materialFile->GetCustomData2Count() > 0)
// 		{
// 			if (isSprite)
// 			{
// 				shaderData.CodeVS = Replace(shaderData.CodeVS,
// 											"//$C_IN2$",
// 											"LAYOUT(" + std::to_string(layoutOffset) + ") " + "IN " +
// 												GetType(materialFile->GetCustomData2Count()) + " atCustomData2;");
// 			}
// 			shaderData.CodeVS = Replace(shaderData.CodeVS,
// 										"//$C_OUT2$",
// 										"LAYOUT(" + std::to_string(pvLayoutOffset) + ") " + "OUT mediump " +
// 											GetType(materialFile->GetCustomData2Count()) + " v_CustomData2;");
// 			shaderData.CodePS = Replace(shaderData.CodePS,
// 										"//$C_PIN2$",
// 										"LAYOUT(" + std::to_string(pvLayoutOffset) + ") " + "IN mediump " +
// 											GetType(materialFile->GetCustomData2Count()) + " v_CustomData2;");
// 		}

		return shaderData;
	}
};

} // namespace GLSL

} // namespace Effekseer
