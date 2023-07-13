#pragma once

#include <string>
#include <vector>

namespace Rml {

#if defined __MINGW32__
#  define RMLUI_ATTRIBUTE_FORMAT_PRINTF(i, f) __attribute__((format (__MINGW_PRINTF_FORMAT, i, f)))
#elif defined __GNUC__ || defined __clang__
#  define RMLUI_ATTRIBUTE_FORMAT_PRINTF(i, f) __attribute__((format (printf, i, f)))
#else
#  define RMLUI_ATTRIBUTE_FORMAT_PRINTF(i, f)
#endif

std::string CreateString(size_t max_size, const char* format, ...) RMLUI_ATTRIBUTE_FORMAT_PRINTF(2,3);

template <typename  T>
T FromString(const std::string& str, T def = T{});
template <typename  T>
std::string ToString(const T& v);

namespace StringUtilities {
	void ExpandString(std::vector<std::string>& string_list, const std::string& string, const char delimiter);
	void ExpandString2(std::vector<std::string>& string_list, const std::string& string, const char delimiter, char quote_character, char unquote_character, bool ignore_repeated_delimiters = false);

	std::string ToLower(const std::string& string);

	inline bool IsWhitespace(const char x) {
		return (x == '\r' || x == '\n' || x == ' ' || x == '\t' || x == '\f');
	}

	std::string StripWhitespace(const std::string& string);

	template <typename T>
	inline T SeekBackwardUTF8(T p, T p_begin) {
		while ((p + 1) != p_begin && (*p & 0b1100'0000) == 0b1000'0000)
			--p;
		return p;
	}
}

}
