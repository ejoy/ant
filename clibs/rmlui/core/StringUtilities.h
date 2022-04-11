/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#ifndef RMLUI_CORE_STRINGUTILITIES_H
#define RMLUI_CORE_STRINGUTILITIES_H

#include <string>
#include <vector>

namespace Rml {

/**
	Helper functions for string manipulation.
	@author Lloyd Weehuizen
 */

// Tell the compiler of printf-like functions, warns on incorrect usage.
#if defined __MINGW32__
#  define RMLUI_ATTRIBUTE_FORMAT_PRINTF(i, f) __attribute__((format (__MINGW_PRINTF_FORMAT, i, f)))
#elif defined __GNUC__ || defined __clang__
#  define RMLUI_ATTRIBUTE_FORMAT_PRINTF(i, f) __attribute__((format (printf, i, f)))
#else
#  define RMLUI_ATTRIBUTE_FORMAT_PRINTF(i, f)
#endif

/// Construct a string using sprintf-style syntax.
std::string CreateString(size_t max_size, const char* format, ...) RMLUI_ATTRIBUTE_FORMAT_PRINTF(2,3);

/// Format to a string using sprintf-style syntax.
int FormatString(std::string& string, size_t max_size, const char* format, ...) RMLUI_ATTRIBUTE_FORMAT_PRINTF(3,4);

template <typename  T>
T FromString(const std::string& str, T def = T{});
template <typename  T>
std::string ToString(const T& v);

enum class Character : char32_t { Null, Replacement = 0xfffd };

namespace StringUtilities
{
	/// Expands character-delimited list of values in a single string to a whitespace-trimmed list
	/// of values.
	/// @param[out] string_list Resulting list of values.
	/// @param[in] string std::string to expand.
	/// @param[in] delimiter Delimiter found between entries in the string list.
	void ExpandString(std::vector<std::string>& string_list, const std::string& string, const char delimiter);
	/// Expands character-delimited list of values with custom quote characters.
	/// @param[out] string_list Resulting list of values.
	/// @param[in] string std::string to expand.
	/// @param[in] delimiter Delimiter found between entries in the string list.
	/// @param[in] quote_character Begin quote
	/// @param[in] unquote_character End quote
	/// @param[in] ignore_repeated_delimiters If true, repeated values of the delimiter will not add additional entries to the list.
	void ExpandString(std::vector<std::string>& string_list, const std::string& string, const char delimiter, char quote_character, char unquote_character, bool ignore_repeated_delimiters = false);

	/// Converts upper-case characters in string to lower-case.
	std::string ToLower(const std::string& string);

	// Replaces all occurences of 'search' in 'subject' with 'replace'.
	std::string Replace(std::string subject, const std::string& search, const std::string& replace);
	// Replaces all occurences of 'search' in 'subject' with 'replace'.
	std::string Replace(std::string subject, char search, char replace);

	/// Checks if a given value is a whitespace character.
	inline bool IsWhitespace(const char x)
	{
		return (x == '\r' || x == '\n' || x == ' ' || x == '\t' || x == '\f');
	}

	/// Strip whitespace characters from the beginning and end of a string.
	std::string StripWhitespace(const std::string& string);

	/// Strip whitespace characters from the beginning and end of a string.
	std::string StripWhitespace(std::string_view string);

	// Decode the first code point in a zero-terminated UTF-8 string.
	Character ToCharacter(const char* p);


	// Seek forward in a UTF-8 string, skipping continuation bytes.
	template <typename T>
	inline T SeekForwardUTF8(T p, T p_end)
	{
		while (p != p_end && (*p & 0b1100'0000) == 0b1000'0000)
			++p;
		return p;
	}
	// Seek backward in a UTF-8 string, skipping continuation bytes.
	template <typename T>
	inline T SeekBackwardUTF8(T p, T p_begin)
	{
		while ((p + 1) != p_begin && (*p & 0b1100'0000) == 0b1000'0000)
			--p;
		return p;
	}
}

class StringIteratorU8 {
public:
	StringIteratorU8(const std::string& string);

	// Seeks forward to the next UTF-8 character. Iterator must be valid.
	StringIteratorU8& operator++();
	
	// Returns the codepoint at the current position. The iterator must be dereferencable.
	inline Character operator*() const { return StringUtilities::ToCharacter(get()); }

	// Returns false when the iterator is located just outside the valid part of the string.
	explicit inline operator bool() const { return p != view.end(); }

	bool operator==(const StringIteratorU8& other) const { return p == other.p; }
	bool operator!=(const StringIteratorU8& other) const { return !(*this == other); }

	// Return a pointer to the current position.
	inline const char* get() const { return &*p; }

	// Return offset from the beginning of string. Note: Can return negative if decremented.
	std::ptrdiff_t offset() const { return p - view.begin(); }

private:
	std::string_view view;
	// 'p' can be dereferenced if and only if inside [view.begin, view.end)
	std::string_view::iterator p;

	inline void SeekForward();
	inline void SeekBack();
};

}
#endif
