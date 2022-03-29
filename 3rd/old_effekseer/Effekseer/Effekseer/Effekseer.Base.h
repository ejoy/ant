
#ifndef __EFFEKSEER_BASE_H__
#define __EFFEKSEER_BASE_H__

#include "Effekseer.Base.Pre.h"

#include <assert.h>
#include <float.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <array>
#include <cfloat>
#include <chrono>
#include <iterator>
#include <list>
#include <map>
#include <mutex>
#include <queue>
#include <set>
#include <string>
#include <thread>
#include <vector>

#ifdef _WIN32
#define EFK_STDCALL __stdcall
#else
#define EFK_STDCALL
#endif

typedef char16_t EFK_CHAR;

namespace Effekseer
{

struct Color;

class ManagerImplemented;
class EffectImplemented;
class EffectNodeImplemented;
class EffectNodeRoot;
class EffectNodeSprite;
class EffectNodeRibbon;
class EffectNodeModel;

class InstanceGlobal;
class InstanceContainer;
class Instance;
class InstanceChunk;
class InstanceGroup;

class FileReader;
class FileWriter;
class FileInterface;
class InternalScript;

#ifdef _DEBUG_EFFEKSEER
#define EffekseerPrintDebug(...) printf(__VA_ARGS__)
#else
#define EffekseerPrintDebug(...)
#endif

/**
	@brief	A state of instances
*/
enum eInstanceState
{
	/**
		@brief	Active
	*/
	INSTANCE_STATE_ACTIVE,

	/**
		@brief	Removing
	*/
	INSTANCE_STATE_REMOVING,
	/**
		@brief	Removed
	*/
	INSTANCE_STATE_REMOVED,

	INSTANCE_STATE_DWORD = 0x7fffffff,
};

/**
	@brief	A type of node
*/
enum eEffectNodeType
{
	EFFECT_NODE_TYPE_ROOT = -1,
	EFFECT_NODE_TYPE_NONE = 0,
	EFFECT_NODE_TYPE_SPRITE = 2,
	EFFECT_NODE_TYPE_RIBBON = 3,
	EFFECT_NODE_TYPE_RING = 4,
	EFFECT_NODE_TYPE_MODEL = 5,
	EFFECT_NODE_TYPE_TRACK = 6,

	EFFECT_NODE_TYPE_DWORD = 0x7fffffff,
};

class StringHelper
{
public:
	template <typename T>
	static std::vector<std::basic_string<T>> Split(const std::basic_string<T>& s, T delim)
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

	template <typename T, typename U>
	static std::basic_string<T> To(const U* str)
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
	template <typename T>
	static std::basic_string<T> Normalize(const std::vector<std::basic_string<T>>& paths)
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
	template <typename T>
	static std::basic_string<T> Normalize(const std::basic_string<T>& path)
	{
		if (path.size() == 0)
			return path;

		auto paths =
			StringHelper::Split(StringHelper::Replace(path, StringHelper::To<T>("\\"), StringHelper::To<T>("/")), static_cast<T>('/'));

		return Normalize(paths);
	}

	template <typename T>
	static std::basic_string<T> Relative(const std::basic_string<T>& targetPath, const std::basic_string<T>& basePath)
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

	template <typename T>
	static std::basic_string<T> Absolute(const std::basic_string<T>& targetPath, const std::basic_string<T>& basePath)
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

} // namespace Effekseer

#endif // __EFFEKSEER_BASE_H__
