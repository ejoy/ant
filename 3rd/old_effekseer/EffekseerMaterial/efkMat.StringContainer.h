#pragma once

#include "efkMat.Base.h"

namespace EffekseerMaterial
{

class StringContainer
{
private:
	static std::unordered_map<std::string, std::string> values;

public:
	StringContainer() = default;
	virtual ~StringContainer() = default;

	static std::string& GetValue(const char* key, const char* defaultValue = nullptr);

	static bool AddValue(const char* key, const char* value);

	static void Clear();
};

} // namespace EffekseerMaterial