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

#include "Debug.h"

namespace Rml {

template <typename SourceType, typename DestType>
bool TypeConverter<SourceType, DestType>::Convert(const SourceType& /*src*/, DestType& /*dest*/)
{
	Log::Message(Log::Level::Error, "No converter specified.");
	return false;
}

#if defined(RMLUI_PLATFORM_WIN32) && defined(__MINGW32__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat"
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-extra-args"
#endif

///
/// Full Specialisations
///

#define BASIC_CONVERTER(s, d) \
template<>	\
class TypeConverter< s, d > \
{ \
public: \
	static bool Convert(const s& src, d& dest) \
	{ \
		dest = (d)src; \
		return true; \
	} \
}

#define BASIC_CONVERTER_BOOL(s, d) \
template<>	\
class TypeConverter< s, d > \
{ \
public: \
	static bool Convert(const s& src, d& dest) \
	{ \
		dest = src != 0; \
		return true; \
	} \
}

#define PASS_THROUGH(t)	BASIC_CONVERTER(t, t)

/////////////////////////////////////////////////
// Simple pass through definitions for converting 
// to the same type (direct copy)
/////////////////////////////////////////////////
PASS_THROUGH(int);
PASS_THROUGH(unsigned int);
PASS_THROUGH(int64_t);
PASS_THROUGH(float);
PASS_THROUGH(double);
PASS_THROUGH(bool);
PASS_THROUGH(char);
PASS_THROUGH(Character);
PASS_THROUGH(Color);
PASS_THROUGH(std::string);

// Pointer types need to be typedef'd
typedef void* voidPtr;
PASS_THROUGH(voidPtr);

/////////////////////////////////////////////////
// Simple Types
/////////////////////////////////////////////////
BASIC_CONVERTER(bool, int);
BASIC_CONVERTER(bool, unsigned int);
BASIC_CONVERTER(bool, int64_t);
BASIC_CONVERTER(bool, float);
BASIC_CONVERTER(bool, double);

BASIC_CONVERTER_BOOL(int, bool);
BASIC_CONVERTER(int, unsigned int);
BASIC_CONVERTER(int, int64_t);
BASIC_CONVERTER(int, float);
BASIC_CONVERTER(int, double);

BASIC_CONVERTER_BOOL(int64_t, bool);
BASIC_CONVERTER(int64_t, int);
BASIC_CONVERTER(int64_t, float);
BASIC_CONVERTER(int64_t, double);
BASIC_CONVERTER(int64_t, unsigned int);

BASIC_CONVERTER_BOOL(float, bool);
BASIC_CONVERTER(float, int);
BASIC_CONVERTER(float, int64_t);
BASIC_CONVERTER(float, double);
BASIC_CONVERTER(float, unsigned int);

BASIC_CONVERTER_BOOL(double, bool);
BASIC_CONVERTER(double, int);
BASIC_CONVERTER(double, int64_t);
BASIC_CONVERTER(double, float);
BASIC_CONVERTER(double, unsigned int);

BASIC_CONVERTER(char, Character);

/////////////////////////////////////////////////
// From string converters
/////////////////////////////////////////////////

#define STRING_FLOAT_CONVERTER(type) \
template<> \
class TypeConverter< std::string, type > \
{ \
public: \
	static bool Convert(const std::string& src, type& dest) \
	{ \
		dest = (type) atof(src.c_str()); \
		return true; \
	} \
}
STRING_FLOAT_CONVERTER(float);
STRING_FLOAT_CONVERTER(double);

template<>
class TypeConverter< std::string, int >
{
public:
	static bool Convert(const std::string& src, int& dest)
	{
		return sscanf(src.c_str(), "%d", &dest) == 1;
	}
};

template<>
class TypeConverter< std::string, unsigned int >
{
public:
	static bool Convert(const std::string& src, unsigned int& dest)
	{
		return sscanf(src.c_str(), "%u", &dest) == 1;
	}
};

template<>
class TypeConverter< std::string, int64_t >
{
public:
	static bool Convert(const std::string& src, int64_t& dest)
	{
		return sscanf(src.c_str(), "%" SCNd64, &dest) == 1;
	}
};

template<>
class TypeConverter< std::string, byte >
{
public:
	static bool Convert(const std::string& src, byte& dest)
	{
		return sscanf(src.c_str(), "%hhu", &dest) == 1;
	}
};

template<>
class TypeConverter< std::string, bool >
{
public:
	static bool Convert(const std::string& src, bool& dest)
	{
		std::string lower = StringUtilities::ToLower(src);
		if (lower == "1" || lower == "true")
		{
			dest = true;
			return true;
		}
		else if (lower == "0" || lower == "false")
		{
			dest = false;
			return true;
		}
		return false;
	}
};

template< typename DestType, typename InternalType, int count >
class TypeConverterStringVector
{
public:
	static bool Convert(const std::string& src, DestType& dest)
	{
		std::vector<std::string> string_list;
		StringUtilities::ExpandString(string_list, src);
		if (string_list.size() < count)
			return false;
		for (int i = 0; i < count; i++)
		{
			if (!TypeConverter< std::string, InternalType >::Convert(string_list[i], dest[i]))
				return false;
		}
		return true;
	}
};

#define STRING_VECTOR_CONVERTER(type, internal_type, count) \
template<> \
class TypeConverter< std::string, type > \
{ \
public: \
	static bool Convert(const std::string& src, type& dest) \
	{ \
		return TypeConverterStringVector< type, internal_type, count >::Convert(src, dest); \
	} \
}

STRING_VECTOR_CONVERTER(Color, byte, 4);

/////////////////////////////////////////////////
// To std::string Converters
/////////////////////////////////////////////////

#define FLOAT_STRING_CONVERTER(type) \
template<> \
class TypeConverter< type, std::string > \
{ \
public: \
	static bool Convert(const type& src, std::string& dest) \
	{ \
		if(FormatString(dest, 32, "%.3f", src) == 0) \
			return false; \
		StringUtilities::TrimTrailingDotZeros(dest); \
		return true; \
	} \
}
FLOAT_STRING_CONVERTER(float);
FLOAT_STRING_CONVERTER(double);

template<>
class TypeConverter< int, std::string >
{
public:
	static bool Convert(const int& src, std::string& dest)
	{
		return FormatString(dest, 32, "%d", src) > 0;
	}
};

template<>
class TypeConverter< unsigned int, std::string >
{
public:
	static bool Convert(const unsigned int& src, std::string& dest)
	{
		return FormatString(dest, 32, "%u", src) > 0;
	}
};

template<>
class TypeConverter< int64_t, std::string >
{
public:
	static bool Convert(const int64_t& src, std::string& dest)
	{
		return FormatString(dest, 32, "%" PRId64, src) > 0;
	}
};

template<>
class TypeConverter< byte, std::string >
{
public:
	static bool Convert(const byte& src, std::string& dest)
	{
		return FormatString(dest, 32, "%hhu", src) > 0;
	}
};

template<>
class TypeConverter< bool, std::string >
{
public:
	static bool Convert(const bool& src, std::string& dest)
	{
		dest = src ? "1" : "0";
		return true;
	}
};

template<>
class TypeConverter< char*, std::string >
{
public:
	static bool Convert(char* const & src, std::string& dest)
	{
		dest = src;
		return true;
	}
};

template< typename SourceType, typename InternalType, int count >
class TypeConverterVectorString
{
public:
	static bool Convert(const SourceType& src, std::string& dest)
	{
		dest = "";
		for (int i = 0; i < count; i++)
		{
			std::string value;
			if (!TypeConverter< InternalType, std::string >::Convert(src[i], value))
				return false;
			
			dest += value;
			if (i < count - 1)
				dest += ", ";
		}
		return true;
	}
};

#define VECTOR_STRING_CONVERTER(type, internal_type, count) \
template<> \
class TypeConverter< type, std::string > \
{ \
public: \
	static bool Convert(const type& src, std::string& dest) \
	{ \
		return TypeConverterVectorString< type, internal_type, count >::Convert(src, dest); \
	} \
}

VECTOR_STRING_CONVERTER(Color, byte, 4);
#undef PASS_THROUGH
#undef BASIC_CONVERTER
#undef BASIC_CONVERTER_BOOL
#undef FLOAT_STRING_CONVERTER
#undef STRING_FLOAT_CONVERTER
#undef STRING_VECTOR_CONVERTER
#undef VECTOR_STRING_CONVERTER

#if defined(RMLUI_PLATFORM_WIN32) && defined(__MINGW32__)
#pragma GCC diagnostic pop
#pragma GCC diagnostic pop
#endif

} // namespace Rml
