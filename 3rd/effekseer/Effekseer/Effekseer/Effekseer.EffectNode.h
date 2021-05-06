
#ifndef __EFFEKSEER_EFFECTNODE_H__
#define __EFFEKSEER_EFFECTNODE_H__

//----------------------------------------------------------------------------------
// Include
//----------------------------------------------------------------------------------
#include "Effekseer.Base.h"
#include "Effekseer.Color.h"
#include "Effekseer.FCurves.h"
#include "Effekseer.InternalStruct.h"
#include "Effekseer.RectF.h"
#include "Effekseer.Vector3D.h"
#include "Sound/Effekseer.SoundPlayer.h"

#include "Effekseer.Effect.h"
#include "ForceField/ForceFields.h"
#include "Noise/CurlNoise.h"
#include "Parameter/DynamicParameter.h"
#include "Parameter/Easing.h"
#include "Parameter/Effekseer.Parameters.h"
#include "SIMD/Utils.h"
#include "Utils/BinaryVersion.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum class BindType : int32_t
{
	NotBind = 0,
	NotBind_Root = 3,
	WhenCreating = 1,
	Always = 2,
};

enum class TranslationParentBindType : int32_t
{
	NotBind = 0,
	NotBind_Root = 3,
	WhenCreating = 1,
	Always = 2,
	NotBind_FollowParent = 4,
	WhenCreating_FollowParent = 5,
};

bool operator==(const TranslationParentBindType& lhs, const BindType& rhs);

enum class ModelReferenceType : int32_t
{
	File,
	Procedural,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
class StandardColorParameter
{
public:
	enum
	{
		Fixed = 0,
		Random = 1,
		Easing = 2,
		FCurve_RGBA = 3,
		Parameter_DWORD = 0x7fffffff,
	} type;

	union
	{
		struct
		{
			Color all;
		} fixed;

		struct
		{
			random_color all;
		} random;

		struct
		{
			easing_color all;
		} easing;

		struct
		{
			FCurveVectorColor* FCurve;
		} fcurve_rgba;
	};

	StandardColorParameter()
	{
		type = Fixed;
	}

	~StandardColorParameter()
	{
		if (type == FCurve_RGBA)
		{
			ES_SAFE_DELETE(fcurve_rgba.FCurve);
		}
	}

	void load(uint8_t*& pos, int32_t version)
	{
		memcpy(&type, pos, sizeof(int));
		pos += sizeof(int);

		if (type == Fixed)
		{
			memcpy(&fixed, pos, sizeof(fixed));
			pos += sizeof(fixed);
		}
		else if (type == Random)
		{
			random.all.load(version, pos);
		}
		else if (type == Easing)
		{
			easing.all.load(version, pos);
		}
		else if (type == FCurve_RGBA)
		{
			fcurve_rgba.FCurve = new FCurveVectorColor();
			int32_t size = fcurve_rgba.FCurve->Load(pos, version);
			pos += size;
		}
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterCommonValues_8
{
	int MaxGeneration;
	BindType TranslationBindType;
	BindType RotationBindType;
	BindType ScalingBindType;
	int RemoveWhenLifeIsExtinct;
	int RemoveWhenParentIsRemoved;
	int RemoveWhenChildrenIsExtinct;
	random_int life;
	float GenerationTime;
	float GenerationTimeOffset;
};

struct ParameterCommonValues
{
	int32_t RefEqMaxGeneration = -1;
	RefMinMax RefEqLife;
	RefMinMax RefEqGenerationTime;
	RefMinMax RefEqGenerationTimeOffset;

	int MaxGeneration = 1;
	TranslationParentBindType TranslationBindType = TranslationParentBindType::Always;
	BindType RotationBindType = BindType::Always;
	BindType ScalingBindType = BindType::Always;
	int RemoveWhenLifeIsExtinct = 1;
	int RemoveWhenParentIsRemoved = 0;
	int RemoveWhenChildrenIsExtinct = 0;
	random_int life;
	random_float GenerationTime;
	random_float GenerationTimeOffset;

	ParameterCommonValues()
	{
		life.max = 1;
		life.min = 1;
		GenerationTime.max = 1;
		GenerationTime.min = 1;
		GenerationTimeOffset.max = 0;
		GenerationTimeOffset.min = 0;
	}
};

struct ParameterDepthValues
{
	float DepthOffset;
	bool IsDepthOffsetScaledWithCamera;
	bool IsDepthOffsetScaledWithParticleScale;
	ZSortType ZSort;
	int32_t DrawingPriority;
	float SoftParticle;

	NodeRendererDepthParameter DepthParameter;

	ParameterDepthValues()
	{
		DepthOffset = 0;
		IsDepthOffsetScaledWithCamera = false;
		IsDepthOffsetScaledWithParticleScale = false;
		ZSort = ZSortType::None;
		DrawingPriority = 0;
		SoftParticle = 0.0f;
	}
};

struct SteeringBehaviorParameter
{
	random_float MaxFollowSpeed;
	random_float SteeringSpeed;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum ParameterTranslationType
{
	ParameterTranslationType_Fixed = 0,
	ParameterTranslationType_PVA = 1,
	ParameterTranslationType_Easing = 2,
	ParameterTranslationType_FCurve = 3,
	ParameterTranslationType_NurbsCurve = 4,
	ParameterTranslationType_ViewOffset = 5,

	ParameterTranslationType_None = 0x7fffffff - 1,

	ParameterTranslationType_DWORD = 0x7fffffff,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterTranslationFixed
{
	int32_t RefEq = -1;

	Vector3D Position;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterTranslationPVA
{
	RefMinMax RefEqP;
	RefMinMax RefEqV;
	RefMinMax RefEqA;
	random_vector3d location;
	random_vector3d velocity;
	random_vector3d acceleration;
};

struct ParameterTranslationEasing
{
	RefMinMax RefEqS;
	RefMinMax RefEqE;
	easing_vector3d location;
};

struct ParameterTranslationNurbsCurve
{
	int32_t Index;
	float Scale;
	float MoveSpeed;
	int32_t LoopType;
};

struct ParameterTranslationViewOffset
{
	random_float distance;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

enum class LocationAbsType : int32_t
{
	None = 0,
	Gravity = 1,
	AttractiveForce = 2,
};

struct LocationAbsParameter
{
	LocationAbsType type = LocationAbsType::None;

	union
	{
		struct
		{

		} none;

		SIMD::Vec3f gravity;

		struct
		{
			float force;
			float control;
			float minRange;
			float maxRange;
		} attractiveForce;
	};
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum ParameterRotationType
{
	ParameterRotationType_Fixed = 0,
	ParameterRotationType_PVA = 1,
	ParameterRotationType_Easing = 2,
	ParameterRotationType_AxisPVA = 3,
	ParameterRotationType_AxisEasing = 4,

	ParameterRotationType_FCurve = 5,

	ParameterRotationType_None = 0x7fffffff - 1,

	ParameterRotationType_DWORD = 0x7fffffff,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterRotationFixed
{
	int32_t RefEq = -1;
	Vector3D Position;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterRotationPVA
{
	RefMinMax RefEqP;
	RefMinMax RefEqV;
	RefMinMax RefEqA;
	random_vector3d rotation;
	random_vector3d velocity;
	random_vector3d acceleration;
};

struct ParameterRotationEasing
{
	RefMinMax RefEqS;
	RefMinMax RefEqE;
	easing_vector3d rotation;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterRotationAxisPVA
{
	random_vector3d axis;
	random_float rotation;
	random_float velocity;
	random_float acceleration;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterRotationAxisEasing
{
	random_vector3d axis;
	ParameterEasingFloat easing{Version16Alpha9, Version16Alpha9};
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum ParameterScalingType
{
	ParameterScalingType_Fixed = 0,
	ParameterScalingType_PVA = 1,
	ParameterScalingType_Easing = 2,
	ParameterScalingType_SinglePVA = 3,
	ParameterScalingType_SingleEasing = 4,
	ParameterScalingType_FCurve = 5,
	ParameterScalingType_SingleFCurve = 6,

	ParameterScalingType_None = 0x7fffffff - 1,

	ParameterScalingType_DWORD = 0x7fffffff,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterScalingFixed
{
	int32_t RefEq = -1;

	Vector3D Position;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterScalingPVA
{
	RefMinMax RefEqP;
	RefMinMax RefEqV;
	RefMinMax RefEqA;

	random_vector3d Position;
	random_vector3d Velocity;
	random_vector3d Acceleration;
};

struct ParameterScalingEasing
{
	RefMinMax RefEqS;
	RefMinMax RefEqE;
	easing_vector3d Position;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterScalingSinglePVA
{
	random_float Position;
	random_float Velocity;
	random_float Acceleration;
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterGenerationLocation
{
	int EffectsRotation;

	enum class AxisType : int32_t
	{
		X,
		Y,
		Z,
	};

	enum
	{
		TYPE_POINT = 0,
		TYPE_SPHERE = 1,
		TYPE_MODEL = 2,
		TYPE_CIRCLE = 3,
		TYPE_LINE = 4,

		TYPE_DWORD = 0x7fffffff,
	} type;

	enum eModelType
	{
		MODELTYPE_RANDOM = 0,
		MODELTYPE_VERTEX = 1,
		MODELTYPE_VERTEX_RANDOM = 2,
		MODELTYPE_FACE = 3,
		MODELTYPE_FACE_RANDOM = 4,

		MODELTYPE_DWORD = 0x7fffffff,
	};

	enum eCircleType
	{
		CIRCLE_TYPE_RANDOM = 0,
		CIRCLE_TYPE_ORDER = 1,
		CIRCLE_TYPE_REVERSE_ORDER = 2,
	};

	enum class LineType : int32_t
	{
		Random = 0,
		Order = 1,
	};

	union
	{
		struct
		{
			random_vector3d location;
		} point;

		struct
		{
			random_float radius;
			random_float rotation_x;
			random_float rotation_y;
		} sphere;

		struct
		{
			ModelReferenceType Reference;
			int32_t index;
			eModelType type;
		} model;

		struct
		{
			int32_t division;
			random_float radius;
			random_float angle_start;
			random_float angle_end;
			eCircleType type;
			AxisType axisDirection;
			random_float angle_noize;
		} circle;

		struct
		{
			int32_t division;
			random_vector3d position_start;
			random_vector3d position_end;
			random_float position_noize;
			LineType type;
		} line;
	};

	void load(uint8_t*& pos, int32_t version)
	{
		memcpy(&EffectsRotation, pos, sizeof(int));
		pos += sizeof(int);

		memcpy(&type, pos, sizeof(int));
		pos += sizeof(int);

		if (type == TYPE_POINT)
		{
			memcpy(&point, pos, sizeof(point));
			pos += sizeof(point);
		}
		else if (type == TYPE_SPHERE)
		{
			memcpy(&sphere, pos, sizeof(sphere));
			pos += sizeof(sphere);
		}
		else if (type == TYPE_MODEL)
		{
			model.Reference = ModelReferenceType::File;

			if (version >= Version16Alpha3)
			{
				memcpy(&model.Reference, pos, sizeof(int32_t));
				pos += sizeof(int32_t);
			}

			memcpy(&model.index, pos, sizeof(int32_t));
			pos += sizeof(int32_t);

			memcpy(&model.type, pos, sizeof(int32_t));
			pos += sizeof(int32_t);
		}
		else if (type == TYPE_CIRCLE)
		{
			if (version < 10)
			{
				memcpy(&circle, pos, sizeof(circle) - sizeof(circle.axisDirection) - sizeof(circle.angle_noize));
				pos += sizeof(circle) - sizeof(circle.axisDirection) - sizeof(circle.angle_noize);
				circle.axisDirection = AxisType::Z;
				circle.angle_noize.max = 0;
				circle.angle_noize.min = 0;
			}
			else
			{
				memcpy(&circle, pos, sizeof(circle));
				pos += sizeof(circle);
			}
		}
		else if (type == TYPE_LINE)
		{
			memcpy(&line, pos, sizeof(line));
			pos += sizeof(line);
		}
	}
};

enum ParameterCustomDataType : int32_t
{
	None = 0,
	Fixed2D = 20,
	Random2D = 21,
	Easing2D = 22,
	FCurve2D = 23,
	Fixed4D = 40,
	FCurveColor = 53,
	DynamicInput = 60,
	Unknown,
};

struct ParameterCustomDataFixed
{
	vector2d Values;
};

struct ParameterCustomDataRandom
{
	random_vector2d Values;
};

struct ParameterCustomDataEasing
{
	easing_vector2d Values;
};

struct ParameterCustomDataFCurve
{
	FCurveVector2D* Values;
};

struct ParameterCustomDataFCurveColor
{
	FCurveVectorColor* Values;
};

struct ParameterCustomData
{
	ParameterCustomDataType Type = ParameterCustomDataType::None;

	union
	{
		ParameterCustomDataFixed Fixed;
		ParameterCustomDataRandom Random;
		ParameterCustomDataEasing Easing;
		ParameterCustomDataFCurve FCurve;
		std::array<float, 4> Fixed4D;
		ParameterCustomDataFCurveColor FCurveColor;
	};

	ParameterCustomData() = default;

	~ParameterCustomData()
	{
		if (Type == ParameterCustomDataType::FCurve2D)
		{
			ES_SAFE_DELETE(FCurve.Values);
		}

		if (Type == ParameterCustomDataType::FCurveColor)
		{
			ES_SAFE_DELETE(FCurveColor.Values);
		}
	}

	void load(uint8_t*& pos, int32_t version)
	{
		memcpy(&Type, pos, sizeof(int));
		pos += sizeof(int);

		if (Type == ParameterCustomDataType::None)
		{
		}
		else if (Type == ParameterCustomDataType::Fixed2D)
		{
			memcpy(&Fixed.Values, pos, sizeof(Fixed));
			pos += sizeof(Fixed);
		}
		else if (Type == ParameterCustomDataType::Random2D)
		{
			memcpy(&Random.Values, pos, sizeof(Random));
			pos += sizeof(Random);
		}
		else if (Type == ParameterCustomDataType::Easing2D)
		{
			memcpy(&Easing.Values, pos, sizeof(Easing));
			pos += sizeof(Easing);
		}
		else if (Type == ParameterCustomDataType::FCurve2D)
		{
			FCurve.Values = new FCurveVector2D();
			pos += FCurve.Values->Load(pos, version);
		}
		else if (Type == ParameterCustomDataType::Fixed4D)
		{
			memcpy(Fixed4D.data(), pos, sizeof(float) * 4);
			pos += sizeof(float) * 4;
		}
		else if (Type == ParameterCustomDataType::FCurveColor)
		{
			FCurveColor.Values = new FCurveVectorColor();
			pos += FCurveColor.Values->Load(pos, version);
		}
		else if (Type == ParameterCustomDataType::DynamicInput)
		{
		}
		else
		{
			assert(0);
		}
	}
};

struct ParameterRendererCommon
{
	static const int32_t UVParameterNum = 6;

	RendererMaterialType MaterialType = RendererMaterialType::Default;

	//! texture index except a file
	int32_t ColorTextureIndex = -1;

	//! texture index except a file
	int32_t Texture2Index = -1;

	//! texture index except a file
	int32_t AlphaTextureIndex = -1;

	//! texture index except a file
	int32_t UVDistortionTextureIndex = -1;

	//! texture index except a file
	int32_t BlendTextureIndex = -1;

	//! texture index except a file
	int32_t BlendAlphaTextureIndex = -1;

	//! texture index except a file
	int32_t BlendUVDistortionTextureIndex = -1;

	//! material index in MaterialType::File
	MaterialRenderData MaterialData;

	AlphaBlendType AlphaBlend = AlphaBlendType::Opacity;

	std::array<TextureFilterType, TextureSlotMax> FilterTypes;
	std::array<TextureWrapType, TextureSlotMax> WrapTypes;

	float UVDistortionIntensity = 1.0f;

	int32_t TextureBlendType = -1;

	float BlendUVDistortionIntensity = 1.0f;

	float EmissiveScaling = 1.0f;

	bool ZWrite = false;

	bool ZTest = false;

	//! this value is not unused
	bool Distortion = false;

	float DistortionIntensity = 0;

	BindType ColorBindType = BindType::NotBind;

	//! pass into a renderer (to make easy to send parameters, it should be refactored)
	NodeRendererBasicParameter BasicParameter;

	ParameterCustomData CustomData1;
	ParameterCustomData CustomData2;

	enum
	{
		FADEIN_ON = 1,
		FADEIN_OFF = 0,

		FADEIN_DWORD = 0x7fffffff,
	} FadeInType;

	struct
	{
		float Frame;
		easing_float_without_random Value;
	} FadeIn;

	enum
	{
		FADEOUT_ON = 1,
		FADEOUT_OFF = 0,

		FADEOUT_DWORD = 0x7fffffff,
	} FadeOutType;

	struct
	{
		float Frame;
		easing_float_without_random Value;
	} FadeOut;

	enum
	{
		UV_DEFAULT = 0,
		UV_FIXED = 1,
		UV_ANIMATION = 2,
		UV_SCROLL = 3,
		UV_FCURVE = 4,

		UV_DWORD = 0x7fffffff,
	} UVTypes[UVParameterNum];

	/**
	@brief	UV Parameter
	@note
	for Compatibility
	*/
	struct UVScroll_09
	{
		rectf Position;
		vector2d Speed;
	};

	union
	{
		struct
		{
		} Default;

		struct
		{
			rectf Position;
		} Fixed;

		struct
		{
			rectf Position;
			int32_t FrameLength;
			int32_t FrameCountX;
			int32_t FrameCountY;

			enum
			{
				LOOPTYPE_ONCE = 0,
				LOOPTYPE_LOOP = 1,
				LOOPTYPE_REVERSELOOP = 2,

				LOOPTYPE_DWORD = 0x7fffffff,
			} LoopType;

			random_int StartFrame;

			enum
			{
				NONE = 0,
				LERP = 1,
			} InterpolationType;

		} Animation;

		struct
		{
			random_vector2d Position;
			random_vector2d Size;
			random_vector2d Speed;
		} Scroll;

		struct
		{
			FCurveVector2D* Position;
			FCurveVector2D* Size;
		} FCurve;
	} UVs[UVParameterNum];

	ParameterRendererCommon()
	{
		FadeInType = FADEIN_OFF;
		FadeOutType = FADEOUT_OFF;
		const int32_t ArraySize = sizeof(UVTypes) / sizeof(UVTypes[0]);
		for (int32_t i = 0; i < ArraySize; i++)
		{
			UVTypes[i] = UV_DEFAULT;
		}

		FilterTypes.fill(TextureFilterType::Nearest);
		WrapTypes.fill(TextureWrapType::Repeat);
	}

	~ParameterRendererCommon()
	{
		const int32_t ArraySize = sizeof(UVTypes) / sizeof(UVTypes[0]);
		for (int32_t i = 0; i < ArraySize; i++)
		{
			if (UVTypes[i] == UV_FCURVE)
			{
				ES_SAFE_DELETE(UVs[i].FCurve.Position);
				ES_SAFE_DELETE(UVs[i].FCurve.Size);
			}
		}
	}

	void reset()
	{
		// with constructor
		// memset(this, 0, sizeof(ParameterRendererCommon));
	}

	void load(uint8_t*& pos, int32_t version)
	{
		// memset(this, 0, sizeof(ParameterRendererCommon));

		if (version >= 15)
		{
			memcpy(&MaterialType, pos, sizeof(int));
			pos += sizeof(int);

			Distortion = MaterialType == RendererMaterialType::BackDistortion;

			if (MaterialType == RendererMaterialType::Default || MaterialType == RendererMaterialType::Lighting)
			{
				if (version >= 1600)
				{
					memcpy(&EmissiveScaling, pos, sizeof(float));
					pos += sizeof(float);
				}
				else
				{
					EmissiveScaling = 1.0f;
				}
			}

			if (MaterialType == RendererMaterialType::Default || MaterialType == RendererMaterialType::BackDistortion ||
				MaterialType == RendererMaterialType::Lighting)
			{
				memcpy(&ColorTextureIndex, pos, sizeof(int));
				pos += sizeof(int);

				memcpy(&Texture2Index, pos, sizeof(int));
				pos += sizeof(int);

				if (version >= 1600)
				{
					memcpy(&AlphaTextureIndex, pos, sizeof(int));
					pos += sizeof(int);

					memcpy(&UVDistortionTextureIndex, pos, sizeof(int));
					pos += sizeof(int);

					memcpy(&BlendTextureIndex, pos, sizeof(int));
					pos += sizeof(int);

					memcpy(&BlendAlphaTextureIndex, pos, sizeof(int));
					pos += sizeof(int);

					memcpy(&BlendUVDistortionTextureIndex, pos, sizeof(int));
					pos += sizeof(int);
				}
			}
			else
			{
				memcpy(&MaterialData.MaterialIndex, pos, sizeof(int));
				pos += sizeof(int);

				int32_t textures = 0;
				int32_t uniforms = 0;

				memcpy(&textures, pos, sizeof(int));
				pos += sizeof(int);

				MaterialData.MaterialTextures.resize(textures);
				if (MaterialData.MaterialTextures.size() > 0)
				{
					memcpy(MaterialData.MaterialTextures.data(), pos, sizeof(MaterialTextureParameter) * textures);
				}
				pos += (sizeof(MaterialTextureParameter) * textures);

				memcpy(&uniforms, pos, sizeof(int));
				pos += sizeof(int);

				MaterialData.MaterialUniforms.resize(uniforms);
				if (MaterialData.MaterialUniforms.size() > 0)
				{
					memcpy(MaterialData.MaterialUniforms.data(), pos, sizeof(float) * 4 * uniforms);
				}
				pos += (sizeof(float) * 4 * uniforms);
			}
		}
		else
		{
			memcpy(&ColorTextureIndex, pos, sizeof(int));
			pos += sizeof(int);
		}

		memcpy(&AlphaBlend, pos, sizeof(int));
		pos += sizeof(int);

		memcpy(&FilterTypes[0], pos, sizeof(int));
		pos += sizeof(int);

		memcpy(&WrapTypes[0], pos, sizeof(int));
		pos += sizeof(int);

		if (version >= 15)
		{
			memcpy(&FilterTypes[1], pos, sizeof(int));
			pos += sizeof(int);

			memcpy(&WrapTypes[1], pos, sizeof(int));
			pos += sizeof(int);
		}
		else
		{
			FilterTypes[1] = FilterTypes[0];
			WrapTypes[1] = WrapTypes[0];
		}

		if (version >= 1600)
		{
			for (size_t i = 2; i < 7; i++)
			{
				memcpy(&FilterTypes[i], pos, sizeof(int));
				pos += sizeof(int);

				memcpy(&WrapTypes[i], pos, sizeof(int));
				pos += sizeof(int);
			}
		}
		else
		{
			for (size_t i = 2; i < 7; i++)
			{
				FilterTypes[i] = FilterTypes[0];
				WrapTypes[i] = WrapTypes[0];
			}
		}

		if (version >= 5)
		{
			int32_t zwrite, ztest = 0;

			memcpy(&ztest, pos, sizeof(int32_t));
			pos += sizeof(int32_t);

			memcpy(&zwrite, pos, sizeof(int32_t));
			pos += sizeof(int32_t);

			ZWrite = zwrite != 0;
			ZTest = ztest != 0;
		}
		else
		{
			ZWrite = false;
			ZTest = true;
		}

		memcpy(&FadeInType, pos, sizeof(int));
		pos += sizeof(int);

		if (FadeInType == FADEIN_ON)
		{
			memcpy(&FadeIn, pos, sizeof(FadeIn));
			pos += sizeof(FadeIn);
		}

		memcpy(&FadeOutType, pos, sizeof(int));
		pos += sizeof(int);

		if (FadeOutType == FADEOUT_ON)
		{
			memcpy(&FadeOut, pos, sizeof(FadeOut));
			pos += sizeof(FadeOut);
		}

		memcpy(&UVTypes[0], pos, sizeof(int));
		pos += sizeof(int);

		auto LoadUVParameter = [&](const int UVIndex) {
			const auto& UVType = UVTypes[UVIndex];
			auto& UV = UVs[UVIndex];

			if (UVType == UV_DEFAULT)
			{
			}
			else if (UVType == UV_FIXED)
			{
				memcpy(&UV.Fixed, pos, sizeof(UV.Fixed));
				pos += sizeof(UV.Fixed);
			}
			else if (UVType == UV_ANIMATION)
			{
				memcpy(&UV.Animation.Position, pos, sizeof(UV.Animation.Position));
				pos += sizeof(UV.Animation.Position);

				memcpy(&UV.Animation.FrameLength, pos, sizeof(UV.Animation.FrameLength));
				pos += sizeof(UV.Animation.FrameLength);

				memcpy(&UV.Animation.FrameCountX, pos, sizeof(UV.Animation.FrameCountX));
				pos += sizeof(UV.Animation.FrameCountX);

				memcpy(&UV.Animation.FrameCountY, pos, sizeof(UV.Animation.FrameCountY));
				pos += sizeof(UV.Animation.FrameCountY);

				memcpy(&UV.Animation.LoopType, pos, sizeof(UV.Animation.LoopType));
				pos += sizeof(UV.Animation.LoopType);

				memcpy(&UV.Animation.StartFrame, pos, sizeof(UV.Animation.StartFrame));
				pos += sizeof(UV.Animation.StartFrame);

				if (version >= 1600 && UVIndex == 0)
				{
					memcpy(&UV.Animation.InterpolationType, pos, sizeof(UV.Animation.InterpolationType));
					pos += sizeof(UV.Animation.InterpolationType);
				}
			}
			else if (UVType == UV_SCROLL)
			{
				memcpy(&UV.Scroll, pos, sizeof(UV.Scroll));
				pos += sizeof(UV.Scroll);
			}
			else if (UVType == UV_FCURVE)
			{
				UV.FCurve.Position = new FCurveVector2D();
				UV.FCurve.Size = new FCurveVector2D();
				pos += UV.FCurve.Position->Load(pos, version);
				pos += UV.FCurve.Size->Load(pos, version);
			}
		};

		LoadUVParameter(0);

		if (version >= 1600)
		{
			// alpha texture
			memcpy(&UVTypes[1], pos, sizeof(int));
			pos += sizeof(int);

			LoadUVParameter(1);

			// uv distortion texture
			memcpy(&UVTypes[2], pos, sizeof(int));
			pos += sizeof(int);

			LoadUVParameter(2);

			// uv distortion intensity
			memcpy(&UVDistortionIntensity, pos, sizeof(int));
			pos += sizeof(int);

			// blend texture
			memcpy(&UVTypes[3], pos, sizeof(int));
			pos += sizeof(int);

			LoadUVParameter(3);

			// blend type
			memcpy(&TextureBlendType, pos, sizeof(int));
			pos += sizeof(int);

			// blend alpha texture
			memcpy(&UVTypes[4], pos, sizeof(int));
			pos += sizeof(int);

			LoadUVParameter(4);

			// blend alpha texture
			memcpy(&UVTypes[5], pos, sizeof(int));
			pos += sizeof(int);

			LoadUVParameter(5);

			// blend uv distortion intensity
			memcpy(&BlendUVDistortionIntensity, pos, sizeof(int));
			pos += sizeof(int);
		}

		if (version >= 10)
		{
			memcpy(&ColorBindType, pos, sizeof(int32_t));
			pos += sizeof(int32_t);
		}
		else
		{
			ColorBindType = BindType::NotBind;
		}

		if (version >= 9)
		{
			if (version < 15)
			{
				int32_t distortion = 0;

				memcpy(&distortion, pos, sizeof(int32_t));
				pos += sizeof(int32_t);

				Distortion = distortion > 0;

				if (Distortion)
				{
					MaterialType = RendererMaterialType::BackDistortion;
				}
			}

			memcpy(&DistortionIntensity, pos, sizeof(float));
			pos += sizeof(float);
		}

		if (version >= 15)
		{
			CustomData1.load(pos, version);
			CustomData2.load(pos, version);
		}

		// copy to basic parameter
		BasicParameter.AlphaBlend = AlphaBlend;
		BasicParameter.TextureFilters = FilterTypes;
		BasicParameter.TextureWraps = WrapTypes;

		BasicParameter.DistortionIntensity = DistortionIntensity;
		BasicParameter.MaterialType = MaterialType;
		BasicParameter.TextureIndexes[0] = ColorTextureIndex;
		BasicParameter.TextureIndexes[1] = Texture2Index;
		BasicParameter.TextureIndexes[2] = AlphaTextureIndex;
		BasicParameter.TextureIndexes[3] = UVDistortionTextureIndex;
		BasicParameter.TextureIndexes[4] = BlendTextureIndex;
		BasicParameter.TextureIndexes[5] = BlendAlphaTextureIndex;
		BasicParameter.TextureIndexes[6] = BlendUVDistortionTextureIndex;

		BasicParameter.UVDistortionIntensity = UVDistortionIntensity;

		BasicParameter.TextureBlendType = TextureBlendType;

		BasicParameter.BlendUVDistortionIntensity = BlendUVDistortionIntensity;

		if (UVTypes[0] == UV_ANIMATION)
		{
			BasicParameter.EnableInterpolation = (UVs[0].Animation.InterpolationType != UVs[0].Animation.NONE);
			BasicParameter.UVLoopType = UVs[0].Animation.LoopType;
			BasicParameter.InterpolationType = UVs[0].Animation.InterpolationType;
			BasicParameter.FlipbookDivideX = UVs[0].Animation.FrameCountX;
			BasicParameter.FlipbookDivideY = UVs[0].Animation.FrameCountY;
		}
		else
		{
			BasicParameter.EnableInterpolation = false;
		}

		BasicParameter.EmissiveScaling = EmissiveScaling;

		if (BasicParameter.MaterialType == RendererMaterialType::File)
		{
			BasicParameter.MaterialRenderDataPtr = &MaterialData;
		}
		else
		{
			BasicParameter.MaterialRenderDataPtr = nullptr;
		}

		if (BasicParameter.MaterialType != RendererMaterialType::Lighting)
		{
			BasicParameter.TextureFilters[1] = TextureFilterType::Nearest;
			BasicParameter.TextureWraps[1] = TextureWrapType::Clamp;
		}
	}
};

struct ParameterAlphaCutoff
{
	enum EType : int32_t
	{
		FIXED,
		FOUR_POINT_INTERPOLATION,
		EASING,
		F_CURVE,

		FPI = FOUR_POINT_INTERPOLATION,
	} Type;

	struct
	{
		int32_t RefEq = -1;
		float Threshold = 0.0f;
	} Fixed;

	struct
	{
		random_float BeginThreshold;
		random_int TransitionFrameNum;
		random_float No2Threshold;
		random_float No3Threshold;
		random_int TransitionFrameNum2;
		random_float EndThreshold;
	} FourPointInterpolation;

	ParameterEasingFloat Easing{Version16Alpha1, Version16Alpha1};

	struct
	{
		FCurveScalar* Threshold;
	} FCurve;

	float EdgeThreshold = 0.0f;
	Color EdgeColor = Color(0, 0, 0, 0);
	float EdgeColorScaling = 0.0f;

	ParameterAlphaCutoff()
		: Type(ParameterAlphaCutoff::EType::FIXED)
	{
	}

	~ParameterAlphaCutoff()
	{
		if (Type == EType::F_CURVE)
		{
			ES_SAFE_DELETE(FCurve.Threshold);
		}
	}

	void load(uint8_t*& pos, int32_t version)
	{
		memcpy(&Type, pos, sizeof(int32_t));
		pos += sizeof(int32_t);

		int32_t BufferSize = 0;
		memcpy(&BufferSize, pos, sizeof(int32_t));
		pos += sizeof(int32_t);

		switch (Type)
		{
		case Effekseer::ParameterAlphaCutoff::EType::FIXED:
			memcpy(&Fixed, pos, BufferSize);
			break;
		case Effekseer::ParameterAlphaCutoff::EType::FPI:
			memcpy(&FourPointInterpolation, pos, BufferSize);
			break;
		case Effekseer::ParameterAlphaCutoff::EType::EASING:
			Easing.Load(pos, BufferSize, version);
			break;
		case Effekseer::ParameterAlphaCutoff::EType::F_CURVE:
			FCurve.Threshold = new FCurveScalar();
			FCurve.Threshold->Load(pos, version);
			break;
		}

		pos += BufferSize;

		memcpy(&EdgeThreshold, pos, sizeof(int32_t));
		pos += sizeof(int32_t);

		memcpy(&EdgeColor, pos, sizeof(Color));
		pos += sizeof(int32_t);

		if (version >= Version16Alpha7)
		{
			memcpy(&EdgeColorScaling, pos, sizeof(float));
			pos += sizeof(float);
		}
		else
		{
			int32_t temp = 0;
			memcpy(&temp, pos, sizeof(int32_t));
			pos += sizeof(int32_t);
			EdgeColorScaling = static_cast<float>(temp);
		}
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum ParameterSoundType
{
	ParameterSoundType_None = 0,
	ParameterSoundType_Use = 1,

	ParameterSoundType_DWORD = 0x7fffffff,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum ParameterSoundPanType
{
	ParameterSoundPanType_2D = 0,
	ParameterSoundPanType_3D = 1,

	ParameterSoundPanType_DWORD = 0x7fffffff,
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
struct ParameterSound
{
	int32_t WaveId;
	random_float Volume;
	random_float Pitch;
	ParameterSoundPanType PanType;
	random_float Pan;
	float Distance;
	random_int Delay;
};

/**
	@brief	a factor to calculate original parameter for dynamic parameter
*/
struct DynamicFactorParameter
{
	std::array<float, 3> Tra;
	std::array<float, 3> TraInv;
	std::array<float, 3> Rot;
	std::array<float, 3> RotInv;
	std::array<float, 3> Scale;
	std::array<float, 3> ScaleInv;

	DynamicFactorParameter()
	{
		Tra.fill(1.0f);
		TraInv.fill(1.0f);
		Rot.fill(1.0f);
		RotInv.fill(1.0f);
		Scale.fill(1.0f);
		ScaleInv.fill(1.0f);
	}
};

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
enum eRenderingOrder
{
	RenderingOrder_FirstCreatedInstanceIsFirst = 0,
	RenderingOrder_FirstCreatedInstanceIsLast = 1,

	RenderingOrder_DWORD = 0x7fffffff,
};

/**
@brief	ノードインスタンス生成クラス
@note
エフェクトのノードの実体を生成する。
*/
class EffectNodeImplemented : public EffectNode, public SIMD::AlignedAllocationPolicy<16>
{
	friend class Manager;
	friend class EffectImplemented;
	friend class Instance;

protected:
	// 所属しているパラメーター
	Effect* m_effect;

	//! a generation in the node tree
	int generation_;

	// 子ノード
	std::vector<EffectNodeImplemented*> m_Nodes;

	RefPtr<RenderingUserData> renderingUserData_;

	// コンストラクタ
	EffectNodeImplemented(Effect* effect, unsigned char*& pos);

	// デストラクタ
	virtual ~EffectNodeImplemented();

	void LoadParameter(unsigned char*& pos, EffectNode* parent, const SettingRef& setting);

	// 初期化
	void Initialize();

	//! calculate custom data
	void CalcCustomData(const Instance* instance, std::array<float, 4>& customData1, std::array<float, 4>& customData2);

public:
	/**
	@brief	\~english Whether to draw the node.
	\~japanese このノードを描画するか?

	@note
	\~english
	普通は描画されないノードは、描画の種類が変更されて、描画しないノードになる。ただし、色の継承をする場合、描画のみを行わないノードになる。
	\~japanese For nodes that are not normally rendered, the rendering type is changed to become a node that does not render. However, when
	color inheritance is done, it becomes a node which does not perform drawing only.
	*/
	bool IsRendered;

	ParameterCommonValues CommonValues;

	SteeringBehaviorParameter SteeringBehaviorParam;

	ParameterTranslationType TranslationType;
	ParameterTranslationFixed TranslationFixed;
	ParameterTranslationPVA TranslationPVA;
	ParameterEasingSIMDVec3 TranslationEasing;
	// ParameterTranslationEasing TranslationEasing;
	FCurveVector3D* TranslationFCurve;
	ParameterTranslationNurbsCurve TranslationNurbsCurve;
	ParameterTranslationViewOffset TranslationViewOffset;
	LocalForceFieldParameter LocalForceField;

	ParameterRotationType RotationType;
	ParameterRotationFixed RotationFixed;
	ParameterRotationPVA RotationPVA;

	ParameterEasingSIMDVec3 RotationEasing;
	// ParameterRotationEasing RotationEasing;
	FCurveVector3D* RotationFCurve;

	ParameterRotationAxisPVA RotationAxisPVA;
	ParameterRotationAxisEasing RotationAxisEasing;

	ParameterScalingType ScalingType;
	ParameterScalingFixed ScalingFixed;
	ParameterScalingPVA ScalingPVA;
	ParameterEasingSIMDVec3 ScalingEasing;
	// ParameterScalingEasing ScalingEasing;
	ParameterScalingSinglePVA ScalingSinglePVA;
	ParameterEasingFloat ScalingSingleEasing{Version16Alpha9, Version16Alpha9};
	FCurveVector3D* ScalingFCurve;
	FCurveScalar* ScalingSingleFCurve = nullptr;

	ParameterGenerationLocation GenerationLocation;

	ParameterDepthValues DepthValues;

	ParameterRendererCommon RendererCommon;

	ParameterAlphaCutoff AlphaCutoff;

	bool EnableFalloff = false;
	FalloffParameter FalloffParam{};

	ParameterSoundType SoundType;
	ParameterSound Sound;

	eRenderingOrder RenderingOrder;

	int32_t RenderingPriority = -1;

	DynamicFactorParameter DynamicFactor;

	Effect* GetEffect() const override;

	int GetGeneration() const override;

	int GetChildrenCount() const override;

	EffectNode* GetChild(int index) const override;

	EffectBasicRenderParameter GetBasicRenderParameter() override;

	void SetBasicRenderParameter(EffectBasicRenderParameter param) override;

	EffectModelParameter GetEffectModelParameter() override;

	virtual void LoadRendererParameter(unsigned char*& pos, const SettingRef& setting);

	/**
	@brief	描画開始
	*/
	virtual void BeginRendering(int32_t count, Manager* manager, void* userData);

	/**
	@brief	グループ描画開始
	*/
	virtual void BeginRenderingGroup(InstanceGroup* group, Manager* manager, void* userData);

	virtual void EndRenderingGroup(InstanceGroup* group, Manager* manager, void* userData);

	/**
	@brief	描画
	*/
	virtual void Rendering(const Instance& instance, const Instance* next_instance, Manager* manager, void* userData);

	/**
	@brief	描画終了
	*/
	virtual void EndRendering(Manager* manager, void* userData);

	/**
	@brief	インスタンスグループ描画時初期化
	*/
	virtual void InitializeRenderedInstanceGroup(InstanceGroup& instanceGroup, Manager* manager);

	/**
	@brief	描画部分初期化
	*/
	virtual void InitializeRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager);

	/**
	@brief	描画部分更新
	*/
	virtual void UpdateRenderedInstance(Instance& instance, InstanceGroup& instanceGroup, Manager* manager);

	/**
	@brief	描画部分更新
	*/
	virtual float GetFadeAlpha(const Instance& instance);

	EffectInstanceTerm CalculateInstanceTerm(EffectInstanceTerm& parentTerm) const override;

	/**
	@brief	エフェクトノード生成
	*/
	static EffectNodeImplemented* Create(Effect* effect, EffectNode* parent, unsigned char*& pos);

	/**
	@brief	ノードの種類取得
	*/
	virtual eEffectNodeType GetType() const
	{
		return EFFECT_NODE_TYPE_NONE;
	}

	RefPtr<RenderingUserData> GetRenderingUserData() override
	{
		return renderingUserData_;
	}

	void SetRenderingUserData(const RefPtr<RenderingUserData>& renderingUserData) override
	{
		renderingUserData_ = renderingUserData;
	}
};
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------

} // namespace Effekseer
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#endif // __EFFEKSEER_EFFECTNODE_H__