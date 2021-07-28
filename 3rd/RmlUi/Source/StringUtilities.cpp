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

#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Debug.h"
#include <algorithm>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

namespace Rml {

static int FormatString(String& string, size_t max_size, const char* format, va_list argument_list)
{
	const int INTERNAL_BUFFER_SIZE = 1024;
	static char buffer[INTERNAL_BUFFER_SIZE];
	char* buffer_ptr = buffer;

	if (max_size + 1 > INTERNAL_BUFFER_SIZE)
		buffer_ptr = new char[max_size + 1];

	int length = vsnprintf(buffer_ptr, max_size, format, argument_list);
	buffer_ptr[length >= 0 ? length : max_size] = '\0';
#ifdef RMLUI_DEBUG
	if (length == -1)
	{
		Log::Message(Log::LT_WARNING, "FormatString: String truncated to %d bytes when processing %s", max_size, format);
	}
#endif

	string = buffer_ptr;

	if (buffer_ptr != buffer)
		delete[] buffer_ptr;

	return length;
}

int FormatString(String& string, size_t max_size, const char* format, ...)
{
	va_list argument_list;
	va_start(argument_list, format);
	int result = FormatString(string, (int)max_size, format, argument_list);
	va_end(argument_list);
	return result;
}
String CreateString(size_t max_size, const char* format, ...)
{
	String result;
	result.reserve(max_size);
	va_list argument_list;
	va_start(argument_list, format);
	FormatString(result, max_size, format, argument_list);
	va_end(argument_list);
	return result;
}

static inline char CharToLower(char c) {
	if (c >= 'A' && c <= 'Z')
		c += char('a' - 'A');
	return c;
}

String StringUtilities::ToLower(const String& string) {
	String str_lower = string;
	std::transform(str_lower.begin(), str_lower.end(), str_lower.begin(), &CharToLower);
	return str_lower;
}

String StringUtilities::ToUpper(const String& string)
{
	String str_upper = string;
	std::transform(str_upper.begin(), str_upper.end(), str_upper.begin(), [](char c) {
		if (c >= 'a' && c <= 'z')
			c -= char('a' - 'A');
		return c;
		}
	);
	return str_upper;
}

String StringUtilities::Replace(String subject, const String& search, const String& replace)
{
	size_t pos = 0;
	while ((pos = subject.find(search, pos)) != String::npos) {
		subject.replace(pos, search.length(), replace);
		pos += replace.length();
	}
	return subject;
}

String StringUtilities::Replace(String subject, char search, char replace)
{
	const size_t size = subject.size();
	for (size_t i = 0; i < size; i++)
	{
		if (subject[i] == search)
			subject[i] = replace;
	}
	return subject;
}


// Expands character-delimited list of values in a single string to a whitespace-trimmed list of values.
void StringUtilities::ExpandString(StringList& string_list, const String& string, const char delimiter)
{	
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


void StringUtilities::ExpandString(StringList& string_list, const String& string, const char delimiter, char quote_character, char unquote_character, bool ignore_repeated_delimiters)
{
	int quote_mode_depth = 0;
	const char* ptr = string.c_str();
	const char* start_ptr = nullptr;
	const char* end_ptr = ptr;

	while (*ptr)
	{
		// Increment the quote depth for each quote character encountered
		if (*ptr == quote_character)
		{
			++quote_mode_depth;
		}
		// And decrement it for every unquote character
		else if (*ptr == unquote_character)
		{
			--quote_mode_depth;
		}

		// If we encounter a delimiter while not in quote mode, add the item to the list
		if (*ptr == delimiter && quote_mode_depth == 0)
		{
			if (start_ptr)
				string_list.emplace_back(start_ptr, end_ptr + 1);
			else if(!ignore_repeated_delimiters)
				string_list.emplace_back();
			start_ptr = nullptr;
		}
		// Otherwise if its not white space or we're in quote mode, advance the pointers
		else if (!IsWhitespace(*ptr) || quote_mode_depth > 0)
		{
			if (!start_ptr)
				start_ptr = ptr;
			end_ptr = ptr;
		}

		ptr++;
	}

	// If there's data pending, add it.
	if (start_ptr)
		string_list.emplace_back(start_ptr, end_ptr + 1);
}

// Joins a list of string values into a single string separated by a character delimiter.
void StringUtilities::JoinString(String& string, const StringList& string_list, const char delimiter)
{
	for (size_t i = 0; i < string_list.size(); i++)
	{
		string += string_list[i];
		if (delimiter != '\0' && i < string_list.size() - 1)
			string += delimiter;
	}
}

String StringUtilities::StripWhitespace(const String& string)
{
	return StripWhitespace(StringView(string));
}

RMLUICORE_API String StringUtilities::StripWhitespace(StringView string)
{
	const char* start = string.begin();
	const char* end = string.end();

	while (start < end && IsWhitespace(*start))
		start++;

	while (end > start&& IsWhitespace(*(end - 1)))
		end--;

	if (start < end)
		return String(start, end);

	return String();
}

void StringUtilities::TrimTrailingDotZeros(String& string)
{
	size_t new_size = string.size();
	for (size_t i = string.size() - 1; i < string.size(); i--)
	{
		if (string[i] == '.')
		{
			new_size = i;
			break;
		}
		else if (string[i] == '0')
			new_size = i;
		else
			break;
	}

	if (new_size < string.size())
		string.resize(new_size);
}

Character StringUtilities::ToCharacter(const char* p)
{
	if ((*p & (1 << 7)) == 0)
		return static_cast<Character>(*p);

	int num_bytes = 0;
	int code = 0;

	if ((*p & 0b1110'0000) == 0b1100'0000)
	{
		num_bytes = 2;
		code = (*p & 0b0001'1111);
	}
	else if ((*p & 0b1111'0000) == 0b1110'0000)
	{
		num_bytes = 3;
		code = (*p & 0b0000'1111);
	}
	else if ((*p & 0b1111'1000) == 0b1111'0000)
	{
		num_bytes = 4;
		code = (*p & 0b0000'0111);
	}
	else
	{
		// Invalid begin byte
		return Character::Null;
	}

	for (int i = 1; i < num_bytes; i++)
	{
		const char byte = *(p + i);
		if ((byte & 0b1100'0000) != 0b1000'0000)
		{
			// Invalid continuation byte
			++p;
			return Character::Null;
		}

		code = ((code << 6) | (byte & 0b0011'1111));
	}

	return static_cast<Character>(code);
}

StringView::StringView()
{
	const char* empty_string = "";
	p_begin = empty_string;
	p_end = empty_string;
}

StringView::StringView(const char* p_begin, const char* p_end) : p_begin(p_begin), p_end(p_end)
{
	RMLUI_ASSERT(p_end >= p_begin);
}
StringView::StringView(const String& string) : p_begin(string.data()), p_end(string.data() + string.size())
{}
StringView::StringView(const String& string, size_t offset) : p_begin(string.data() + offset), p_end(string.data() + string.size())
{}
StringView::StringView(const String& string, size_t offset, size_t count) : p_begin(string.data() + offset), p_end(string.data() + std::min<size_t>(offset + count, string.size()))
{}

bool StringView::operator==(const StringView& other) const { 
	return size() == other.size() && strncmp(p_begin, other.p_begin, size()) == 0; 
}


StringIteratorU8::StringIteratorU8(const char* p_begin, const char* p, const char* p_end) : view(p_begin, p_end), p(p) 
{}
StringIteratorU8::StringIteratorU8(const String& string) : view(string), p(string.data())
{}
StringIteratorU8::StringIteratorU8(const String& string, size_t offset) : view(string), p(string.data() + offset)
{}
StringIteratorU8::StringIteratorU8(const String& string, size_t offset, size_t count) : view(string, 0, offset + count), p(string.data() + offset)
{}
StringIteratorU8& StringIteratorU8::operator++() {
	RMLUI_ASSERT(p < view.end());
	++p;
	SeekForward();
	return *this;
}

inline void StringIteratorU8::SeekForward() {
	p = StringUtilities::SeekForwardUTF8(p, view.end());
}

} // namespace Rml
