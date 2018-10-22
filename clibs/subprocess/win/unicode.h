#pragma once

#include <Windows.h>
#include <vector>
#include <string>
#include <deque>

struct strview {
    template <class T>
    strview(const T& str)
        : buf(str.data())
        , len(str.size())
    { }
    strview(const char* buf, size_t len)
        : buf(buf)
        , len(len)
    { }
    strview(const char* buf)
        : buf(buf)
        , len(strlen(buf))
    { }
    bool empty() const { return buf == 0; }
    const char* data() const { return buf; }
    size_t size() const { return len; }
    const char* buf;
    size_t len;
};

struct wstrview {
    template <class T>
    wstrview(const T& str)
        : buf(str.data())
        , len(str.size())
    { }
    wstrview(const wchar_t* buf, size_t len)
        : buf(buf)
        , len(len)
    { }
    bool empty() const { return buf == 0; }
    const wchar_t* data() const { return buf; }
    size_t size() const { return len; }
    const wchar_t* buf;
    size_t len;
};

std::wstring u2w(const strview& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str.data(), str.size(), NULL, 0);
    if (wlen <= 0) {
        return L"";
    }
    std::vector<wchar_t> result(wlen);
    ::MultiByteToWideChar(CP_UTF8, 0, str.data(), str.size(), result.data(), wlen);
    return std::wstring(result.data(), result.size());
}

std::string w2u(const wstrview& wstr) {
    if (wstr.empty()) {
        return "";
    }
    int len = ::WideCharToMultiByte(CP_UTF8, 0, wstr.data(), wstr.size(), NULL, 0, 0, 0);
    if (len <= 0)
    {
        return "";
    }
    std::vector<char> result(len);
    ::WideCharToMultiByte(CP_UTF8, 0, wstr.data(), wstr.size(), result.data(), len, 0, 0);
    return std::string(result.data(), result.size());
}

std::wstring a2w(const strview& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_ACP, 0, str.data(), str.size(), NULL, 0);
    if (wlen <= 0) {
        return L"";
    }
    std::vector<wchar_t> result(wlen);
    ::MultiByteToWideChar(CP_ACP, 0, str.data(), str.size(), result.data(), wlen);
    return std::wstring(result.data(), result.size());
}

std::string w2a(const wstrview& wstr) {
    if (wstr.empty()) {
        return "";
    }
    int len = ::WideCharToMultiByte(CP_ACP, 0, wstr.data(), wstr.size(), NULL, 0, 0, 0);
    if (len <= 0) {
        return "";
    }
    std::vector<char> result(len);
    ::WideCharToMultiByte(CP_ACP, 0, wstr.data(), wstr.size(), result.data(), len, 0, 0);
    return std::string(result.data(), result.size());
}

std::string a2u(const strview& str) {
    return w2u(a2w(str));
}

std::string u2a(const strview& str) {
    return w2a(u2w(str));
}
