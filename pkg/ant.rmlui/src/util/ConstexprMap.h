#pragma once

#include <utility>

namespace Rml {

template <typename Key, typename Value, size_t N>
class ConstexprMap {
public:
    using key_type = Key;
    using mapped_type = Value;
    using value_type = std::pair<key_type, mapped_type>;
    using size_type = size_t;
    using difference_type = std::ptrdiff_t;
    using const_reference = const value_type&;
    using const_pointer = const value_type*;

    class iterator {
    public:
        constexpr iterator(const value_type* pos_) noexcept : pos(pos_) {}
        constexpr bool operator==(const iterator& rhs) const noexcept { return pos == rhs.pos; }
        constexpr bool operator!=(const iterator& rhs) const noexcept { return pos != rhs.pos; }
        constexpr iterator& operator++() noexcept { ++pos; return *this; }
        constexpr iterator& operator+=(size_t i) noexcept { pos += i; return *this; }
        constexpr iterator operator+(size_t i) const noexcept {  return pos + i; }
        constexpr iterator& operator--() noexcept { --pos; return *this; }
        constexpr iterator& operator-=(size_t i) noexcept { pos -= i; return *this; }
        constexpr size_t operator-(const iterator& rhs) const noexcept { return pos - rhs.pos; }
        constexpr const auto& operator*() const noexcept { return *pos; }
        constexpr const auto* operator->() const noexcept {  return &*pos; }
    private:
        const value_type* pos;
    };
    using const_iterator = iterator;

private:
    static_assert(N > 0, "ConstexprMap is empty");
    value_type data_[N];

    template <typename T, size_t... I>
    constexpr ConstexprMap(const T& data, std::index_sequence<I...>) noexcept
        : data_{ { data[I].first, data[I].second }... } {
        for (auto left = data_, right = data_ + N - 1; data_ < right; right = left, left = data_) {
            for (auto it = data_; it < right; ++it) {
                if (it[1] < it[0]) {
                    it[0].swap(it[1]);
                    left = it;
                }
            }
        }
    }
public:
    template <typename T>
    constexpr ConstexprMap(const T& data) noexcept
        : ConstexprMap(data, std::make_index_sequence<N>())
    {}
    constexpr bool unique() const noexcept {
        for (auto right = data_ + N - 1, it = data_; it < right; ++it) {
            if (!(it[0] < it[1])) {
                return false;
            }
        }
        return true;
    }
    constexpr const mapped_type& at(const key_type& key) const noexcept {
        return find(key)->second;
    }
    constexpr size_t size() const noexcept {
        return N;
    }
    constexpr const_iterator begin() const noexcept {
        return data_;
    }
    constexpr const_iterator cbegin() const noexcept {
        return begin();
    }
    constexpr const_iterator end() const noexcept {
        return data_ + N;
    }
    constexpr const_iterator cend() const noexcept {
        return end();
    }
    constexpr auto lower_bound(const_iterator left, const_iterator right, const key_type& key) const noexcept {
        size_t count = right - left;
        while (count > 0) {
            const size_t step = count / 2;
            right = left + step;
            if (std::less()(right->first, key)) {
                left = ++right;
                count -= step + 1;
            } else {
                count = step;
            }
        }
        return left;
    }
    constexpr auto upper_bound(const_iterator left, const_iterator right, const key_type& key) const noexcept {
        size_t count = right - left;
        while (count > 0) {
            const size_t step = count / 2;
            right = left + step;
            if (!std::less()(key, right->first)) {
                left = ++right;
                count -= step + 1;
            } else {
                count = step;
            }
        }
        return left;
    }
    constexpr const_iterator lower_bound(const key_type& key) const noexcept {
        return lower_bound(data_, data_ + N, key);
    }
    constexpr const_iterator upper_bound(const key_type& key) const noexcept {
        return upper_bound(data_, data_ + N, key);
    }
    constexpr std::pair<const_iterator, const_iterator> equal_range(const key_type& key) const noexcept {
        auto first = lower_bound(key);
        return { first, upper_bound(first, data_ + N, key) };
    }
    constexpr size_t count(const key_type& key) const noexcept {
        const auto range = equal_range(key);
        return range.second - range.first;
    }
    constexpr const_iterator find(const key_type& key) const noexcept {
        auto it = lower_bound(key);
        if (it != data_ + N && !std::less()(key, it->first)) {
            return it;
        } else {
            return end();
        }
    }
    constexpr bool contains(const key_type& key) const noexcept {
        return find(key) != end();
    }
};

template <typename Key, typename Value, size_t N>
constexpr auto MakeConstexprMap(const std::array<std::pair<Key, Value>, N>& items) noexcept {
    return ConstexprMap<Key, Value, N>(items);
}

template <typename Key, typename Value, size_t N>
constexpr auto MakeConstexprMap(const std::pair<Key, Value> (&items)[N]) noexcept {
    return ConstexprMap<Key, Value, N>(items);
}

}
