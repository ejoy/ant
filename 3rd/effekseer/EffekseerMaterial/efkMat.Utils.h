
#pragma once

#include "efkMat.Base.h"

namespace EffekseerMaterial
{

std::string Replace(std::string v, std::string pre, std::string past);
	
#if defined(__APPLE__)
std::string NFCtoNFD(const std::string& v);
std::string NFDtoNFC(const std::string& v);
#endif

struct Vector2DF
{
	float X;
	float Y;

	Vector2DF() : X(0), Y(0) {}

	Vector2DF(float x, float y) : X(x), Y(y) {}
};

std::string EspcapeUserParamName(const char* name);

std::string GetConstantTextureName(int64_t guid);

inline std::string ResolvePath(const std::string& path)
{
#if defined(_WIN32)
	return Replace(path, "\\", "/");
#elif defined(__APPLE__)
	return NFDtoNFC(path);
#else
	return path;
#endif
}

inline std::string ToNativePath(const std::string& path)
{
#if defined(_WIN32)
	return Replace(path, "/", "\\");
#elif defined(__APPLE__)
	return NFCtoNFD(path);
#else
	return path;
#endif
}

bool IsValidName(const char* name);

} // namespace EffekseerMaterial
