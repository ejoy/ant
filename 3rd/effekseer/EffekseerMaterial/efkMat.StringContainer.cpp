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

	if (it != values.end() && it->second != key_)
	{
		return false;
	}

	values[key_] = value;

	return true;
}

bool StringContainer::LoadFromJsonStr(const char* json_str)
{
	picojson::value root_;
	auto err = picojson::parse(root_, json_str);
	if (!err.empty())
	{
		std::cerr << err << std::endl;
		return false;
	}

	picojson::object strs_obj = root_.get<picojson::object>();

	for (auto o : strs_obj)
	{
		auto k = o.first;
		auto v = o.second.get<std::string>();
		AddValue(k.c_str(), v.c_str());
	}

	return true;
}

void StringContainer::Clear() { values.clear(); }

} // namespace EffekseerMaterial