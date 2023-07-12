#include <core/File.h>
#include <vector>

#if defined(_WIN32)
#include <Windows.h>
#endif

namespace Rml {

#if defined(_WIN32)
std::wstring u2w(const std::string_view& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), NULL, 0);
    if (wlen <= 0) {
        return L"";
    }
    std::vector<wchar_t> result(wlen);
    ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), result.data(), (int)wlen);
    return std::wstring(result.data(), result.size());
}
#endif

File::File(const std::string& path) {
#if defined(_WIN32)
    handle = _wfopen(u2w(path).c_str(), L"rb");
#else
    handle = fopen(path.c_str(), "rb");
#endif
}

File::~File() {
    if (handle) {
        fclose(handle);
    }
}

File::operator bool() const {
    return !!handle;
}

size_t File::Read(void* buffer, size_t size) {
    return fread(buffer, 1, size, handle);
}

size_t File::Length() {
    auto current_position = ftell(handle);
    fseek(handle, 0, SEEK_END);
    auto length = ftell(handle);
    fseek(handle, current_position, SEEK_SET);
    return length;
}

}
