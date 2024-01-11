#include <util/StringUtilities.h>
#include <algorithm>

namespace Rml::StringUtilities {

void ExpandString(std::vector<std::string>& string_list, const std::string& string, const char delimiter) {
	char quote = 0;
	bool last_char_delimiter = true;
	const char* ptr = string.c_str();
	const char* start_ptr = nullptr;
	const char* end_ptr = ptr;

	size_t num_delimiter_values = std::count(string.begin(), string.end(), delimiter);
	if (num_delimiter_values == 0)
	{
		string_list.push_back(StripWhitespace(string));
		return;
	}
	string_list.reserve(string_list.size() + num_delimiter_values + 1);

	while (*ptr)
	{
		// Switch into quote mode if the last char was a delimeter ( excluding whitespace )
		// and we're not already in quote mode
		if (last_char_delimiter && !quote && (*ptr == '"' || *ptr == '\''))
		{			
			quote = *ptr;
		}
		// Switch out of quote mode if we encounter a quote that hasn't been escaped
		else if (*ptr == quote && *(ptr-1) != '\\')
		{
			quote = 0;
		}
		// If we encounter a delimiter while not in quote mode, add the item to the list
		else if (*ptr == delimiter && !quote)
		{
			if (start_ptr)
				string_list.emplace_back(start_ptr, end_ptr + 1);
			else
				string_list.emplace_back();
			last_char_delimiter = true;
			start_ptr = nullptr;
		}
		// Otherwise if its not white space or we're in quote mode, advance the pointers
		else if (!IsWhitespace(*ptr) || quote)
		{
			if (!start_ptr)
				start_ptr = ptr;
			end_ptr = ptr;
			last_char_delimiter = false;
		}

		ptr++;
	}

	// If there's data pending, add it.
	if (start_ptr)
		string_list.emplace_back(start_ptr, end_ptr + 1);
}

std::string StripWhitespace(const std::string& s) {
	auto start = s.begin();
	auto end = s.end();
	while (start < end && IsWhitespace(*start))
		start++;
	while (end > start && IsWhitespace(*(end - 1)))
		end--;
	if (start < end)
		return std::string(start, end);
	return std::string();
}

std::string_view StripWhitespace(std::string_view s) {
	auto start = s.begin();
	auto end = s.end();
	while (start < end && IsWhitespace(*start))
		start++;
	while (end > start && IsWhitespace(*(end - 1)))
		end--;
	if (start < end)
		return { start, end };
	return {};
}


}
