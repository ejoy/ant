
#pragma once

#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include <algorithm>
#include <array>
#include <functional>
#include <iostream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace EffekseerMaterial
{

const int UserTextureSlotMax = 6;
const int32_t CompiledMaterialVersion15 = 1;
const int32_t CompiledMaterialVersion16 = 1610;

const int32_t MaterialVersion15 = 3;
const int32_t MaterialVersion16 = 1610;

enum class TextureValueType
{
	Color,
	Value,
};

enum class TextureSamplerType
{
	Repeat,
	Wrap,
	Unknown,
};

enum class ConnectResultType
{
	OK,
	Type,
	Multi,
	Loop,
	SamePin,
	SameDirection,
	SameNode,
};

enum class WarningType
{
	None,
	WrongInputType,
	WrongProperty,
	DifferentSampler,
	InvalidName,
	SameName,
	PixelNodeAndNormal,
};

enum class ValueType
{
	Float1 = 0,
	Float2 = 1,
	Float3 = 2,
	Float4 = 3,
	FloatN,
	Bool,
	Texture,
	String,
	Function,
	Enum,
	Int,
	Unknown,
};

enum class PinDirectionType
{
	Input,
	Output,
};

enum class NodeType
{
	Constant1,
	Constant2,
	Constant3,
	Constant4,

	Parameter1,
	Parameter2,
	Parameter3,
	Parameter4,

	Abs,
	Sine,
	Arctangent2,
	Add,
	Subtract,
	Multiply,
	Divide,
	FMod,

	Step,
	Ceil,
	Floor,
	Frac,
	Max,
	Min,
	Power,
	SquareRoot,
	Clamp,
	DotProduct,
	CrossProduct,
	Normalize,	//! 1500
	LinearInterpolate,

	OneMinus,
	ComponentMask,
	AppendVector,
	TextureCoordinate,
	Panner,

	TextureObject,
	TextureObjectParameter,
	SampleTexture,

	Time,
	EffectScale,
	CameraPositionWS, //! 1500

	VertexNormalWS,
	PixelNormalWS,

	WorldPosition, //! 1500
	VertexColor,
	ObjectScale, //! 1500
	

	CustomData1,
	CustomData2,

	Fresnel,
	Rotator,
	PolarCoords,
	
	DepthFade,

	Comment,
	Function, // Unimplemented
	Output,

// VectrToRadialValue

//! not supported on UE4
#ifdef _DEBUG
	VertexTangentWS,
#endif

};

enum class DefaultType
{
	Value,
	UV,
	Time,
};

class PinParameter;
class NodeParameter;

class Material;
class Pin;
class Node;
class Link;
class Library;

inline bool IsFloatValueType(ValueType vt)
{
	return vt == ValueType::Float1 || vt == ValueType::Float2 || vt == ValueType::Float3 || vt == ValueType::Float4 ||
		   vt == ValueType::FloatN;
}

inline int GetElementCount(ValueType vt)
{
	if (vt == ValueType::Float1)
		return 1;
	if (vt == ValueType::Float2)
		return 2;
	if (vt == ValueType::Float3)
		return 3;
	if (vt == ValueType::Float4)
		return 4;
	return 1;
};

//! copy from Effekseer
class StringHelper
{
public:
	template <typename T> static std::vector<std::basic_string<T>> Split(const std::basic_string<T>& s, T delim)
	{
		std::vector<std::basic_string<T>> elems;

		size_t start = 0;

		for (size_t i = 0; i < s.size(); i++)
		{
			if (s[i] == delim)
			{
				elems.emplace_back(s.substr(start, i - start));
				start = i + 1;
			}
		}

		if (start == s.size())
		{
			elems.emplace_back(std::basic_string<T>());
		}
		else
		{
			elems.emplace_back(s.substr(start, s.size() - start));
		}

		return elems;
	}

	template <typename T>
	static std::basic_string<T> Replace(std::basic_string<T> target, std::basic_string<T> from_, std::basic_string<T> to_)
	{
		auto Pos = target.find(from_);

		while (Pos != std::basic_string<T>::npos)
		{
			target.replace(Pos, from_.length(), to_);
			Pos = target.find(from_, Pos + to_.length());
		}

		return target;
	}

	template <typename T, typename U> static std::basic_string<T> To(const U* str)
	{
		std::basic_string<T> ret;
		size_t len = 0;
		while (str[len] != 0)
		{
			len++;
		}

		ret.resize(len);

		for (size_t i = 0; i < len; i++)
		{
			ret[i] = static_cast<T>(str[i]);
		}

		return ret;
	}
};

class PathHelper
{
private:
	template <typename T> static std::basic_string<T> Normalize(const std::vector<std::basic_string<T>>& paths)
	{
		std::vector<std::basic_string<T>> elems;

		for (size_t i = 0; i < paths.size(); i++)
		{
			if (paths[i] == StringHelper::To<T>(".."))
			{
				if (elems.size() > 0 && elems.back() != StringHelper::To<T>(".."))
				{
					elems.pop_back();
				}
				else
				{
					elems.push_back(StringHelper::To<T>(".."));
				}
			}
			else
			{
				elems.push_back(paths[i]);
			}
		}

		std::basic_string<T> ret;

		for (size_t i = 0; i < elems.size(); i++)
		{
			ret += elems[i];

			if (i != elems.size() - 1)
			{
				ret += StringHelper::To<T>("/");
			}
		}

		return ret;
	}

public:
	template <typename T> static std::basic_string<T> Normalize(const std::basic_string<T>& path)
	{
		if (path.size() == 0)
			return path;

		auto paths =
			StringHelper::Split(StringHelper::Replace(path, StringHelper::To<T>("\\"), StringHelper::To<T>("/")), static_cast<T>('/'));

		return Normalize(paths);
	}

	template <typename T> static std::basic_string<T> Relative(const std::basic_string<T>& targetPath, const std::basic_string<T>& basePath)
	{
		if (basePath.size() == 0 || targetPath.size() == 0)
		{
			return targetPath;
		}

		auto targetPaths = StringHelper::Split(StringHelper::Replace(targetPath, StringHelper::To<T>("\\"), StringHelper::To<T>("/")),
											   static_cast<T>('/'));
		auto basePaths =
			StringHelper::Split(StringHelper::Replace(basePath, StringHelper::To<T>("\\"), StringHelper::To<T>("/")), static_cast<T>('/'));

		if (*(basePath.end() - 1) != static_cast<T>('/') && *(basePath.end() - 1) != static_cast<T>('\\'))
		{
			basePaths.pop_back();
		}

		int32_t offset = 0;
		while (targetPaths.size() > offset && basePaths.size() > offset)
		{
			if (targetPaths[offset] == basePaths[offset])
			{
				offset++;
			}
			else
			{
				break;
			}
		}

		std::basic_string<T> ret;

		for (size_t i = offset; i < basePaths.size(); i++)
		{
			ret += StringHelper::To<T>("../");
		}

		for (size_t i = offset; i < targetPaths.size(); i++)
		{
			ret += targetPaths[i];

			if (i != targetPaths.size() - 1)
			{
				ret += StringHelper::To<T>("/");
			}
		}

		return ret;
	}

	template <typename T> static std::basic_string<T> Absolute(const std::basic_string<T>& targetPath, const std::basic_string<T>& basePath)
	{
		if (targetPath == StringHelper::To<T>(""))
			return StringHelper::To<T>("");

		if (basePath == StringHelper::To<T>(""))
			return targetPath;

		auto targetPaths = StringHelper::Split(StringHelper::Replace(targetPath, StringHelper::To<T>("\\"), StringHelper::To<T>("/")),
											   static_cast<T>('/'));
		auto basePaths =
			StringHelper::Split(StringHelper::Replace(basePath, StringHelper::To<T>("\\"), StringHelper::To<T>("/")), static_cast<T>('/'));

		if (*(basePath.end() - 1) != static_cast<T>('/') && *(basePath.end() - 1) != static_cast<T>('\\'))
		{
			basePaths.pop_back();
		}

		std::copy(targetPaths.begin(), targetPaths.end(), std::back_inserter(basePaths));

		return Normalize(basePaths);
	}
};

} // namespace EffekseerMaterial
