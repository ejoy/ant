#include "efkMat.StringContainer.h"
#include "ThirdParty/picojson.h"

namespace EffekseerMaterial
{
std::unordered_map<std::string, std::string> StringContainer::values;

std::string& StringContainer::GetValue(const char* key, const char* defaultValue)
{
	auto key_ = std::string(key);
	auto it = values.find(key_);

	if (it != values.end())
	{
		return it->second;
	}

	if (defaultValue != nullptr)
	{
		values[key_] = defaultValue;
	}
	else
	{
		values[key_] = key_;
	}

	return values[key_];
}

bool StringContainer::AddValue(const char* key, const char* value)
{
	auto key_ = std::string(key);
	auto it = values.find(key_);

	values[key_] = value;

	return true;
}

void StringContainer::Clear() { values.clear(); }

} // namespace EffekseerMaterial