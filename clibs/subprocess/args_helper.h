#pragma once

#include <string>
#include <deque>

#if defined(_WIN32)
namespace ant::win::subprocess {
#else
namespace ant::posix::subprocess {
#endif

    template <class char_t>
    struct strbuilder {
        struct node {
            size_t size;
            size_t maxsize;
            char_t* data;
            node(size_t maxsize)
                : size(0)
                , maxsize(maxsize)
                , data(new char_t[maxsize])
            { }
            ~node() {
                delete[] data;
            }
            char_t* release() {
                char_t* r = data;
                data = nullptr;
                return r;
            }
            bool append(const char_t* str, size_t n) {
                if (size + n > maxsize) {
                    return false;
                }
                memcpy(data + size, str, n * sizeof(char_t));
                size += n;
                return true;
            }
            template <class T, size_t n>
            void operator +=(T(&str)[n]) {
                append(str, n - 1);
            }
            void operator +=(const std::basic_string_view<char_t>& str) {
                append(str.data(), str.size());
            }
        };
        strbuilder() : size(0) { }
        void clear() {
            size = 0;
            data.clear();
        }
        bool append(const char_t* str, size_t n) {
            if (!data.empty() && data.back().append(str, n)) {
                size += n;
                return true;
            }
            size_t m = 1024;
            while (m < n) {
                m *= 2;
            }
            data.emplace_back(m).append(str, n);
            size += n;
            return true;
        }
        template <class T, size_t n>
        strbuilder& operator +=(T(&str)[n]) {
            append(str, n - 1);
            return *this;
        }
        strbuilder& operator +=(const std::basic_string_view<char_t>& s) {
            append(s.data(), s.size());
            return *this;
        }
        char_t* string() {
            node r(size + 1);
            for (auto& s : data) {
                r.append(s.data, s.size);
            }
            char_t empty[] = { '\0' };
            r.append(empty, 1);
            return r.release();
        }
        std::deque<node> data;
        size_t size;
    };

    template <class char_t>
    inline std::basic_string<char_t> quote_arg(const std::basic_string<char_t>& source) {
        size_t len = source.size();
        if (len == 0) {
            return {'\"','\"','\0'};
        }
        if (std::basic_string<char_t>::npos == source.find_first_of({' ','\t','\"'})) {
            return source;
        }
        if (std::basic_string<char_t>::npos == source.find_first_of({'\"','\\'})) {
            return std::basic_string<char_t>({'\"'}) + source + std::basic_string<char_t>({'\"'});
        }
        std::basic_string<char_t> target;
        target += '"';
        int quote_hit = 1;
        for (size_t i = len; i > 0; --i) {
            target += source[i - 1];

            if (quote_hit && source[i - 1] == '\\') {
                target += '\\';
            }
            else if (source[i - 1] == '"') {
                quote_hit = 1;
                target += '\\';
            }
            else {
                quote_hit = 0;
            }
        }
        target += '"';
        for (size_t i = 0; i < target.size() / 2; ++i) {
            std::swap(target[i], target[target.size() - i - 1]);
        }
        return target;
    }
}
