#include <databinding/DataModel.h>
#include <core/Element.h>
#include <core/Log.h>
#include <core/StringUtilities.h>
#include <algorithm>
#include <set>

namespace Rml {

static DataAddress ParseAddress(const std::string& address_str) {
	std::vector<std::string> list;
	StringUtilities::ExpandString(list, address_str, '.');

	DataAddress address;
	address.reserve(list.size() * 2);

	for (const auto& item : list)
	{
		if (item.empty())
			return DataAddress();

		size_t i_open = item.find('[', 0);
		if (i_open == 0)
			return DataAddress();

		address.emplace_back(item.substr(0, i_open));

		while (i_open != std::string::npos)
		{
			size_t i_close = item.find(']', i_open + 1);
			if (i_close == std::string::npos)
				return DataAddress();

			int index = FromString<int>(item.substr(i_open + 1, i_close - i_open), -1);
			if (index < 0)
				return DataAddress();

			address.emplace_back(index);

			i_open = item.find('[', i_close + 1);
		}
		// TODO: Abort on invalid characters among [ ] and after the last found bracket?
	}

	assert(!address.empty() && !address[0].name.empty());

	return address;
}

// Returns an error string on error, or nullptr on success.
static const char* LegalVariableName(const std::string& name) {
	static std::unordered_set<std::string> reserved_names{ "it", "ev", "true", "false", "size", "literal" };
	
	if (name.empty())
		return "Name cannot be empty.";
	
	const std::string name_lower = StringUtilities::ToLower(name);

	const char first = name_lower.front();
	if (!(first >= 'a' && first <= 'z'))
		return "First character must be 'a-z' or 'A-Z'.";

	for (const char c : name_lower)
	{
		if (!(c == '_' || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')))
			return "Name must strictly contain characters a-z, A-Z, 0-9 and under_score.";
	}

	if (reserved_names.count(name_lower) == 1)
		return "Name is reserved.";

	return nullptr;
}

static std::string DataAddressToString(const DataAddress& address) {
	std::string result;
	bool is_first = true;
	for (auto& entry : address)
	{
		if (entry.index >= 0)
			result += '[' + ToString(entry.index) + ']';
		else
		{
			if (!is_first)
				result += ".";
			result += entry.name;
		}
		is_first = false;
	}
	return result;
}

DataModel::DataModel()
{}

DataModel::~DataModel() {
}

bool DataModel::BindVariable(const std::string& name, DataVariable variable) {
	const char* name_error_str = LegalVariableName(name);
	if (name_error_str)
	{
		Log::Message(Log::Level::Warning, "Could not bind data variable '%s'. %s", name.c_str(), name_error_str);
		return false;
	}

	if (!variable)
	{
		Log::Message(Log::Level::Warning, "Could not bind variable '%s' to data model, data type not registered.", name.c_str());
		return false;
	}

	bool inserted = variables.emplace(name, variable).second;
	if (!inserted)
	{
		Log::Message(Log::Level::Warning, "Data model variable with name '%s' already exists.", name.c_str());
		return false;
	}

	return true;
}

void DataModel::CleanDirty() {
	dirty = false;
}

void DataModel::MarkDirty() {
	dirty = true;
}

bool DataModel::IsDirty() const {
	return dirty;
}

}
