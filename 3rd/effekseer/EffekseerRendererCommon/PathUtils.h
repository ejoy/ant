#include <locale>
#include <codecvt>
template <class Facet> struct deletable_facet : Facet
{
	template <class... Args>
	deletable_facet(Args&&... args)
		: Facet(std::forward<Args>(args)...)
	{
	}
	~deletable_facet() {}
};
std::string w2u(const std::u16string& source);
std::u16string u2w(const std::string& source);
std::string get_ant_file_path(const std::string& path);