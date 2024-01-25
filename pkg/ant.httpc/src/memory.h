#pragma once

#include <cstddef>
#include <deque>

struct Memory {
    Memory(size_t sz) noexcept
        : m_data(new std::byte[sz])
        , m_size(sz)
    {}
    ~Memory() noexcept { delete[] m_data; }
    Memory(Memory&& rhs) noexcept
        : m_data(rhs.m_data)
        , m_size(rhs.m_size) {
        rhs.m_data = nullptr;
        rhs.m_size = 0;
    }
    Memory(const Memory& rhs) noexcept = delete;
    Memory& operator=(Memory&&) noexcept = delete;
    Memory& operator=(const Memory&) noexcept = delete;
    const std::byte* data() const noexcept {
        return m_data;
    }
    size_t size() const noexcept {
        return m_size;
    }
    const std::byte& operator[](size_t i) const {
        return m_data[i];
    }
    std::byte& operator[](size_t i) {
        return m_data[i];
    }
    std::byte* m_data;
    size_t m_size;
};

template <size_t N = 1024>
struct MemoryBuilder {
    struct node {
        std::byte data[N];
        void append(size_t pos, const std::byte* str, size_t n) noexcept {
            assert (pos + n <= N);
            memcpy(&data[pos], str, n * sizeof(std::byte));
        }
    };
    MemoryBuilder() noexcept
        : pos(0) {
        data.resize(1);
    }
    void clear() noexcept {
        pos = 0;
        data.resize(1);
    }
    void append(const std::byte* str, size_t n) noexcept {
        if (pos + n <= N) {
            data.back().append(pos, str, n);
            pos += n;
            return;
        }
        size_t m = N - pos;
        data.back().append(pos, str, m);
        data.emplace_back();
        pos = 0;
        append(str + m, n - m);
    }
    Memory release() noexcept {
        size_t sz = (data.size() - 1) * N + pos;
        Memory r(sz);
        for (size_t i = 0; i < data.size() - 1;++i) {
            memcpy(&r[i * N], &data[i], N * sizeof(std::byte));
        }
        memcpy(&r[(data.size() - 1) * N], &data.back(), pos * sizeof(std::byte));
        clear();
        return r;
    }
    std::deque<node> data;
    size_t           pos;
};
