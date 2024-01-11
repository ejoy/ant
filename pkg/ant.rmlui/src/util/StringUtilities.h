#pragma once

#include <string>
#include <vector>

namespace Rml::StringUtilities {
	void ExpandString(std::vector<std::string>& string_list, const std::string& string, const char delimiter);

	inline bool IsWhitespace(const char x) {
		return (x == '\r' || x == '\n' || x == ' ' || x == '\t' || x == '\f');
	}

	std::string StripWhitespace(const std::string& s);
	std::string_view StripWhitespace(std::string_view s);
}
