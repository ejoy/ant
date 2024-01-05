#pragma once

#include <deque>
#include <stdexcept>
#include <memory>
#include <array>
#include <span>

namespace Rml {
    template <class char_t, size_t N = 1024>
    struct strbuilder {
        struct node {
            char_t data[N];
            void append(size_t pos, const char_t* str, size_t n) {
                assert (pos + n <= N);
                memcpy(&data[pos], str, n * sizeof(char_t));
            }
        };
        strbuilder()
            : pos(0) {
            data.resize(1);
        }
        void clear() {
            pos = 0;
            data.resize(1);
        }
        void append(const char_t* str, size_t n) {
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
        template <class T>
        strbuilder& append(const T& v) {
            append((const char_t*)&v, sizeof(T));
            return *this;
        }
        template <class T, size_t n>
        strbuilder& append(T(&str)[n]) {
            append((const char_t*)str, sizeof(T) * (n - 1));
            return *this;
        }
        std::span<char_t> string() {
            size_t sz = (data.size() - 1) * N + pos + 1;
            auto r = new char_t[sz];
            for (size_t i = 0; i < data.size() - 1;++i) {
                memcpy(r + i * N * sizeof(char_t), &data[i], N * sizeof(char_t));
            }
            memcpy(r + (data.size() - 1) * N * sizeof(char_t), &data.back(), pos * sizeof(char_t));
            r[sz-1] = 0;
            clear();
            return {r, sz};
        }
        std::deque<node> data;
        size_t           pos;
    };

    template <class char_t>
    struct strparser {
        strparser(const char_t* str)
            : data(str)
        {}
        template <class T>
        T const& pop() {
            const char_t* prev = data;
            data += sizeof(T);
            return *(T const*)prev;
        }
        const char_t* pop(size_t sz) {
            const char_t* prev = data;
            data += sz;
            return prev;
        }
        const char_t* data;
    };

    template<typename VariantType, typename T, std::size_t Is = 0>
    constexpr std::size_t variant_index() {
        static_assert(Is < std::variant_size_v<VariantType>, "Type not found in variant");
        if constexpr (std::is_same_v<std::variant_alternative_t<Is, VariantType>, T>) {
            return Is;
        } else {
            return variant_index<VariantType, T, Is+1>();
        }
    }

    template <class U, class T>
    inline void PropertyEncodeSize(strbuilder<uint8_t>& b, T const& v) {
        size_t n = v.size();
        assert(n <= std::numeric_limits<U>::max());
        b.append((U)n);
    }

    template <class T>
    inline void PropertyEncode(strbuilder<uint8_t>& b, T const& v) {
        b.append(v);
    }

    template <class ...Args>
    inline void PropertyEncode(strbuilder<uint8_t>& b, std::variant<Args...> const& v) {
        using VariantType = std::variant<Args...>;
        std::visit([&](auto&& arg) {
            using T = std::decay_t<decltype(arg)>;
            b.append((uint8_t)variant_index<VariantType, T>());
            PropertyEncode(b, arg);
        }, v);
    }

    inline void PropertyEncode(strbuilder<uint8_t>& b, std::string const& v) {
        b.append(v.size());
        b.append((const uint8_t*)v.data(), v.size());
    }

    inline void PropertyEncode(strbuilder<uint8_t>& b, Transform const& v) {
        PropertyEncodeSize<uint8_t>(b, v);
        for (auto const& value: v) {
            PropertyEncode(b, (Transforms::Primitive const&)value);
        }
    }

    inline void PropertyEncode(strbuilder<uint8_t>& b, TransitionList const& v) {
        PropertyEncodeSize<uint8_t>(b, v);
        for (auto const& [id, value]: v) {
            b.append(id);
            b.append(value);
        }
    }

    inline void PropertyEncode(strbuilder<uint8_t>& b, Animation const& v) {
        b.append(v.transition);
        b.append(v.num_iterations);
        b.append(v.alternate);
        b.append(v.paused);
        PropertyEncode(b, v.name);
    }

    inline void PropertyEncode(strbuilder<uint8_t>& b, AnimationList const& v) {
        PropertyEncodeSize<uint8_t>(b, v);
        for (auto const& value: v) {
            PropertyEncode(b, value);
        }
    }

    template <class T>
    struct tag {};

    template <class T>
    inline constexpr auto tag_v = tag<T>{};

    template <class T>
    inline T PropertyDecode(tag<T>, strparser<uint8_t>& data) {
        return data.pop<T>();
    }

    template <class VariantType>
    using DecodeVariantFunc = VariantType (*)(strparser<uint8_t>& data);
    template <class VariantType>
    using DecodeVariantJumpTable = std::array<DecodeVariantFunc<VariantType>, std::variant_size_v<VariantType>>;

    template <class VariantItem, class VariantType>
    inline VariantType PropertyDecodeVariant(strparser<uint8_t>& data) {
        return PropertyDecode(tag_v<VariantItem>, data);
    }

    template <size_t Is, class VariantType>
    constexpr void CreateDecodeVariantJumpTable_(DecodeVariantJumpTable<VariantType>& jump) {
        if constexpr (Is < std::variant_size_v<VariantType>) {
            using VariantItem = std::variant_alternative_t<Is, VariantType>;
            jump[Is] = PropertyDecodeVariant<VariantItem, VariantType>;
            CreateDecodeVariantJumpTable_<Is+1, VariantType>(jump);
        }
    }

    template <class VariantType>
    constexpr auto CreateDecodeVariantJumpTable() {
        DecodeVariantJumpTable<VariantType> jump;
        CreateDecodeVariantJumpTable_<0, VariantType>(jump);
        return jump;
    }

    template <class ...Args>
    inline std::variant<Args...> PropertyDecode(tag<std::variant<Args...>>, strparser<uint8_t>& data) {
        using VariantType = std::variant<Args...>;
        constinit static auto jump = CreateDecodeVariantJumpTable<VariantType>();
        uint8_t type = data.pop<uint8_t>();
        if (type >= jump.size()) {
            throw std::runtime_error("decode variant failed.");
        }
        return jump[type](data);
    }

    inline std::string PropertyDecode(tag<std::string>, strparser<uint8_t>& data) {
        size_t sz = data.pop<size_t>();
        return {(const char*)data.pop(sz), sz};
    }

    inline Transform PropertyDecode(tag<Transform>, strparser<uint8_t>& data) {
        size_t n = data.pop<uint8_t>();
        Transform t;
        t.reserve(n);
        for (size_t i = 0; i < n; ++i) {
            t.emplace_back(PropertyDecode(tag_v<Transforms::Primitive>, data));
        }
        return t;
    }

    inline TransitionList PropertyDecode(tag<TransitionList>, strparser<uint8_t>& data) {
        size_t n = data.pop<uint8_t>();
        TransitionList t;
        for (size_t i = 0; i < n; ++i) {
            auto id = data.pop<PropertyId>();
            auto value = data.pop<Transition>();
            t.emplace(std::move(id), std::move(value));
        }
        return t;
    }

    inline Animation PropertyDecode(tag<Animation>, strparser<uint8_t>& data) {
        return {
            data.pop<Transition>(),
            data.pop<int>(),
            data.pop<bool>(),
            data.pop<bool>(),
            PropertyDecode(tag_v<std::string>, data)
        };
    }

    inline AnimationList PropertyDecode(tag<AnimationList>, strparser<uint8_t>& data) {
        size_t n = data.pop<uint8_t>();
        AnimationList t;
        t.reserve(n);
        for (size_t i = 0; i < n; ++i) {
            t.emplace_back(PropertyDecode(tag_v<Animation>, data));
        }
        return t;
    }
}
