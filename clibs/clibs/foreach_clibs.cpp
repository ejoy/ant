#include "foreach_clibs.h"
#include "foreach_eat.h"

class dirpairs {
public:
	dirpairs(fs::path const& o) : p(o) { }
	fs::directory_iterator begin() const { return fs::directory_iterator(p); }
	fs::directory_iterator end()   const { return fs::directory_iterator(); }
	dirpairs(dirpairs const&) = delete;
	dirpairs(dirpairs&&) = delete;
	dirpairs& operator=(dirpairs const&) = delete;
	dirpairs& operator=(dirpairs&&) = delete;
private:
	fs::path const& p;
};

static bool patheq(const std::wstring& lpath, const std::wstring& rpath) {
	const wchar_t* l = lpath.c_str();
	const wchar_t* r = rpath.c_str();
	while ((towlower(*l) == towlower(*r)
		|| (*l == L'\\' && *r == L'/')
		|| (*l == L'/' && *r == L'\\'))
		&& *l) {
		++l; ++r;
	}
	return *l == *r;
}

static bool patheq(const std::wstring& lpath, const std::string& rpath) {
	const wchar_t* l = lpath.c_str();
	const char* r = rpath.c_str();
	while ((towlower(*l) == tolower(*r)
		|| (*l == L'\\' && *r == '/')
		|| (*l == L'/' && *r == '\\'))
		&& *l) {
		++l; ++r;
	}
	return *l == *r;
}

void foreach_clibs(const fs::path& dir, std::function<void(const fs::path&, const std::string&)> fn) {
	for (fs::path const& dll : dirpairs(dir)) {
		if (fs::is_directory(dll)) {
			continue;
		}
		if (!patheq(L".dll", dll.extension().wstring())) {
			continue;
		}
		std::wstring filename = dll.stem().wstring();
		foreach_eat(dll.c_str(), [&](const std::string& api) {
			if (api.substr(0, 8) != "luaopen_") {
				return;
			}
			if (filename.size() + 8 == api.size()) {
				if (patheq(filename, api.substr(8))) {
					fn(dll, api);
					return;
				}
			}
			else if (filename.size() + 8 < api.size() && api[filename.size() + 8] == '_') {
				if (patheq(filename, api.substr(8, filename.size()))) {
					fn(dll, api);
					return;
				}
			}
		});
	}
}
