#include "PathUtils.h"
std::string w2u(const std::u16string& source)
{
	std::wstring_convert<
		deletable_facet<std::codecvt<char16_t, char, std::mbstate_t>>, char16_t> convert;
	return convert.to_bytes(source);
}
std::u16string u2w(const std::string& source)
{
	std::wstring_convert<
		deletable_facet<std::codecvt<char16_t, char, std::mbstate_t>>, char16_t> convert;
	return convert.from_bytes(source);
}