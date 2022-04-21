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

#include <core/StringUtilities.h>
#include <core/Log.h>
#include <algorithm>
#include <assert.h>
#include <stdio.h>
#include <stdarg.h>
#include <string.h>

namespace Rml {

static int FormatString(std::string& string, size_t max_size, const char* format, va_list argument_list)
{
	const int INTERNAL_BUFFER_SIZE = 1024;
	static char buffer[INTERNAL_BUFFER_SIZE];
	char* buffer_ptr = buffer;

	if (max_size + 1 > INTERNAL_BUFFER_SIZE)
		buffer_ptr = new char[max_size + 1];

	int length = vsnprintf(buffer_ptr, max_size, format, argument_list);
	buffer_ptr[length >= 0 ? length : max_size] = '\0';
#if !defined NDEBUG
	if (length == -1)
	{
		Log::Message(Log::Level::Warning, "FormatString: std::string truncated to %d bytes when processing %s", max_size, format);
	}
#endif

	string = buffer_ptr;

	if (buffer_ptr != buffer)
		delete[] buffer_ptr;

	return length;
}

std::string CreateString(size_t max_size, const char* format, ...)
{
	std::string result;
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

std::string StringUtilities::ToLower(const std::string& string) {
	std::string str_lower = string;
	std::transform(str_lower.begin(), str_lower.end(), str_lower.begin(), &CharToLower);
	return str_lower;
}

std::string StringUtilities::Replace(std::string subject, const std::string& search, const std::string& replace)
{
	size_t pos = 0;
	while ((pos = subject.find(search, pos)) != std::string::npos) {
		subject.replace(pos, search.length(), replace);
		pos += replace.length();
	}
	return subject;
}

std::string StringUtilities::Replace(std::string subject, char search, char replace)
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
void StringUtilities::ExpandString(std::vector<std::string>& string_list, const std::string& string, const char delimiter)
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


void StringUtilities::ExpandString2(std::vector<std::string>& string_list, const std::string& string, const char delimiter, char quote_character, char unquote_character, bool ignore_repeated_delimiters)
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

std::string StringUtilities::StripWhitespace(const std::string& s) {
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

StringIteratorU8::StringIteratorU8(const std::string& string) : view(string), p(view.begin())
{}
StringIteratorU8& StringIteratorU8::operator++() {
	assert(p < view.end());
	++p;
	SeekForward();
	return *this;
}

inline void StringIteratorU8::SeekForward() {
	p = StringUtilities::SeekForwardUTF8(p, view.end());
}


template <>
float FromString<float>(const std::string& str, float def) {
	errno = 0;
	float r = strtof(str.c_str(), NULL);
	if (errno != 0) {
		return def;
	}
	return r;
}

template <>
int FromString<int>(const std::string& str, int def) {
	errno = 0;
	long r = strtol(str.c_str(), NULL, 10);
	if (errno != 0) {
		return def;
	}
	return r;
}

template <>
std::string ToString<float>(const float& v) {
	return std::to_string(v);
}

template <>
std::string ToString<int>(const int& v) {
	return std::to_string(v);
}

}
