#include "path_helper.h"
#include "dynarray.h"
#include "error.h"

#if defined(_WIN32)

#include <Windows.h>

// http://blogs.msdn.com/oldnewthing/archive/2004/10/25/247180.aspx
extern "C" IMAGE_DOS_HEADER __ImageBase;

namespace ant::path_helper {
    auto dll_path(void* module_handle)->nonstd::expected<fs::path, std::exception> {
        wchar_t buffer[MAX_PATH];
        DWORD path_len = ::GetModuleFileNameW((HMODULE)module_handle, buffer, _countof(buffer));
        if (path_len == 0) {
            return nonstd::make_unexpected(make_syserror("GetModuleFileNameW"));
        }
        if (path_len < _countof(buffer)) {
            return std::move(fs::path(buffer, buffer + path_len));
        }
        for (DWORD buf_len = 0x200; buf_len <= 0x10000; buf_len <<= 1) {
            std::dynarray<wchar_t> buf(buf_len);
            DWORD path_len = ::GetModuleFileNameW((HMODULE)module_handle, buf.data(), buf_len);
            if (path_len == 0) {
                return nonstd::make_unexpected(make_syserror("GetModuleFileNameW"));
            }
            if (path_len < _countof(buffer)) {
                return std::move(fs::path(buf.data(), buf.data() + path_len));
            }
        }
        return nonstd::make_unexpected(std::runtime_error("::GetModuleFileNameW return too long."));
    }

    auto exe_path()->nonstd::expected<fs::path, std::exception> {
        return dll_path(NULL);
    }

    auto dll_path()->nonstd::expected<fs::path, std::exception> {
        return dll_path(reinterpret_cast<void*>(&__ImageBase));
    }
}

#else

#include <dlfcn.h>
#include <lua.hpp>

namespace ant::path_helper {
    auto dll_path(void* module_handle)->nonstd::expected<fs::path, std::exception> {
        ::Dl_info dl_info;
        dl_info.dli_fname = 0;
        int const ret = ::dladdr(module_handle, &dl_info);
        if (0 != ret && dl_info.dli_fname != NULL) {
            return fs::absolute(dl_info.dli_fname).lexically_normal();
        }
        return nonstd::make_unexpected(std::runtime_error("::dladdr failed."));
    }

    auto exe_path()->nonstd::expected<fs::path, std::exception> {
        return dll_path((void*)&lua_newstate);
    }

    auto dll_path()->nonstd::expected<fs::path, std::exception> {
        return dll_path((void*)&exe_path);
    }
}

#endif

namespace ant::path_helper {
#if defined(_WIN32)
    bool equal(fs::path const& lhs, fs::path const& rhs) {
        fs::path lpath = lhs.lexically_normal();
        fs::path rpath = rhs.lexically_normal();
        const fs::path::value_type* l(lpath.c_str());
        const fs::path::value_type* r(rpath.c_str());
        while ((towlower(*l) == towlower(*r) || (*l == L'\\' && *r == L'/') || (*l == L'/' && *r == L'\\')) && *l) {
            ++l; ++r;
        }
        return *l == *r;
    }
#elif defined(__APPLE__)
    bool equal(fs::path const& lhs, fs::path const& rhs) {
        fs::path lpath = lhs.lexically_normal();
        fs::path rpath = rhs.lexically_normal();
        const fs::path::value_type* l(lpath.c_str());
        const fs::path::value_type* r(rpath.c_str());
        while (towlower(*l) == towlower(*r) && *l) {
            ++l; ++r;
        }
        return *l == *r;
}
#else
    bool equal(fs::path const& lhs, fs::path const& rhs) {
        return lhs.lexically_normal() == rhs.lexically_normal();
    }
#endif
}
