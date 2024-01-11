#pragma once

#include <array>
#include <cstddef>
#include <deque>
#include <functional>
#include <memory>
#include <optional>
#include <span>
#include <stdexcept>
#include <bee/nonstd/unreachable.h>

namespace Rml {
    template <class char_t>
    struct str {
        str(size_t sz)
            : data(new char_t[sz])
            , size(sz)
        {}
        ~str() { delete[] data; }
        str(str&& rhs)
            : data(rhs.data)
            , size(rhs.size) {
            rhs.data = nullptr;
            rhs.size = 0;
        }
        str(const str& rhs) = delete;
        str& operator=(str&&) = delete;
        str& operator=(const str&) = delete;
        const char_t& operator[](size_t i) const {
            return data[i];
        }
        char_t& operator[](size_t i) {
            return data[i];
        }
        std::span<char_t> span() {
            return { data, size };
        }
        char_t* data;
        size_t size;
    };

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
        str<char_t> release() {
            size_t sz = (data.size() - 1) * N + pos + 1;
            str<char_t> r(sz);
            for (size_t i = 0; i < data.size() - 1;++i) {
                memcpy(&r[i * N], &data[i], N * sizeof(char_t));
            }
            memcpy(&r[(data.size() - 1) * N], &data.back(), pos * sizeof(char_t));
            r[sz-1] = 0;
            clear();
            return r;
        }
        std::deque<node> data;
        size_t           pos;
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

    class PropertyBasicView {
    public:
        PropertyBasicView(const std::byte* ptr)
            : ptr(ptr)
        {}
        template <typename T>
        const T& get() const {
            return *(const T*)ptr;
        }
        template <typename T>
        const T& pop() {
            const std::byte* prev = ptr;
            ptr += sizeof(T);
            return *(const T*)prev;
        }
        template <typename T>
        const T* pop(size_t n) {
            const std::byte* prev = ptr;
            ptr += sizeof(T) * n;
            return (const T*)prev;
        }
    protected:
        const std::byte* ptr;
    };


    template <class T>
    struct tag {};

    template <class T>
    inline constexpr auto tag_v = tag<T>{};

    template <typename T, typename... Types>
    constexpr uint8_t PropertyTypeIndex = -1;
    template <typename T, typename... Types>
    constexpr uint8_t PropertyTypeIndex<T, T, Types...> = 0;
    template <typename T, typename U, typename... Types>
    constexpr uint8_t PropertyTypeIndex<T, U, Types...> = 1 + PropertyTypeIndex<T, Types...>;

    template <typename ...Types>
    class PropertyVariantView: public PropertyBasicView {
    public:
        template <typename T>
        static constexpr uint8_t Index = PropertyTypeIndex<T, Types...>;
        PropertyVariantView(const std::byte* ptr)
            : PropertyBasicView(ptr)
        {}
        uint8_t get_index() const {
            return *(const uint8_t*)ptr;
        }
        template <typename T>
            requires (std::is_trivially_destructible_v<T>)
        const T& get() const {
            if (get_index() != Index<T>) {
                throw std::runtime_error("decode property failed.");
            }
            return *(const T*)(ptr + 1);
        }
        template <typename T>
            requires (!std::is_trivially_destructible_v<T>)
        PropertyBasicView get_view() const {
            if (get_index() != Index<T>) {
                throw std::runtime_error("decode property failed.");
            }
            return PropertyBasicView { ptr + 1 };
        }
        template <typename T>
            requires (std::is_trivially_destructible_v<T>)
        const T* get_if() const {
            if (get_index() != Index<T>) {
                return nullptr;
            }
            return (const T*)(ptr + 1);
        }
        template <typename T>
            requires (!std::is_trivially_destructible_v<T>)
        std::optional<PropertyBasicView> get_view_if() const {
            if (get_index() != Index<T>) {
                return std::nullopt;
            }
            return PropertyBasicView { ptr + 1 };
        }

        template <std::size_t I, std::size_t Max>
        struct SwitchCase {
            template <typename Visitor>
            static auto Run(Visitor&& vis, PropertyBasicView v0) {
                if constexpr (I < Max) {
                    using T = std::tuple_element_t<I, std::tuple<Types...>>;
                    if constexpr (std::is_trivially_destructible_v<T>) {
                        return std::invoke(std::forward<Visitor>(vis), v0.get<T>());
                    }
                    else {
                        return std::invoke(std::forward<Visitor>(vis), tag_v<T>, v0);
                    }
                }
                else {
                    return std::invoke(std::forward<Visitor>(vis));
                }
            }
            template <typename Visitor>
            static auto Run(Visitor&& vis, PropertyBasicView v0, PropertyBasicView v1) {
                if constexpr (I < Max) {
                    using T = std::tuple_element_t<I, std::tuple<Types...>>;
                    if constexpr (std::is_trivially_destructible_v<T>) {
                        return std::invoke(std::forward<Visitor>(vis), v0.get<T>(), v1.get<T>());
                    }
                    else {
                        return std::invoke(std::forward<Visitor>(vis), tag_v<T>, v0, v1);
                    }
                }
                else {
                    return std::invoke(std::forward<Visitor>(vis));
                }
            }
        };
        template <typename Visitor>
        auto visit(Visitor&& vis) {
            constexpr static std::size_t Max = sizeof...(Types);
            static_assert(Max <= 8);
            switch (get_index()) {
            case 0: return SwitchCase<0, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 1: return SwitchCase<1, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 2: return SwitchCase<2, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 3: return SwitchCase<3, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 4: return SwitchCase<4, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 5: return SwitchCase<5, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 6: return SwitchCase<6, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            case 7: return SwitchCase<7, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 });
            default:
                return std::invoke(std::forward<Visitor>(vis));
            }
        }
        template <typename Visitor>
        auto visit(Visitor&& vis, PropertyVariantView<Types...> v1) {
            constexpr static std::size_t Max = sizeof...(Types);
            static_assert(Max <= 8);
            auto index0 = get_index();
            if (index0 != v1.get_index()) {
                return std::invoke(std::forward<Visitor>(vis));
            }
            switch (index0) {
            case 0: return SwitchCase<0, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 1: return SwitchCase<1, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 2: return SwitchCase<2, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 3: return SwitchCase<3, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 4: return SwitchCase<4, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 5: return SwitchCase<5, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 6: return SwitchCase<6, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            case 7: return SwitchCase<7, Max>::Run(std::forward<Visitor>(vis), { ptr + 1 }, { v1.ptr + 1 });
            default:
                return std::invoke(std::forward<Visitor>(vis));
            }
        }
    };

    template <class T>
    inline T PropertyDecode(tag<T>, PropertyBasicView& data) {
        return data.pop<T>();
    }

    template <class VariantType>
    using DecodeVariantFunc = VariantType (*)(PropertyBasicView& data);
    template <class VariantType>
    using DecodeVariantJumpTable = std::array<DecodeVariantFunc<VariantType>, std::variant_size_v<VariantType>>;

    template <class VariantItem, class VariantType>
    inline VariantType PropertyDecodeVariant(PropertyBasicView& data) {
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
    inline std::variant<Args...> PropertyDecode(tag<std::variant<Args...>>, PropertyBasicView& data) {
        using VariantType = std::variant<Args...>;
        constinit static auto jump = CreateDecodeVariantJumpTable<VariantType>();
        uint8_t type = data.pop<uint8_t>();
        if (type >= jump.size()) {
            throw std::runtime_error("decode variant failed.");
        }
        return jump[type](data);
    }

    inline std::string PropertyDecode(tag<std::string>, PropertyBasicView& data) {
        size_t sz = data.pop<size_t>();
        return {data.pop<char>(sz), sz};
    }

    inline Transform PropertyDecode(tag<Transform>, PropertyBasicView& data) {
        size_t n = data.pop<uint8_t>();
        Transform t;
        t.reserve(n);
        for (size_t i = 0; i < n; ++i) {
            t.emplace_back(PropertyDecode(tag_v<Transforms::Primitive>, data));
        }
        return t;
    }

    inline TransitionList PropertyDecode(tag<TransitionList>, PropertyBasicView& data) {
        size_t n = data.pop<uint8_t>();
        TransitionList t;
        for (size_t i = 0; i < n; ++i) {
            auto id = data.pop<PropertyId>();
            auto value = data.pop<Transition>();
            t.emplace(std::move(id), std::move(value));
        }
        return t;
    }

    inline Animation PropertyDecode(tag<Animation>, PropertyBasicView& data) {
        return {
            data.pop<Transition>(),
            data.pop<int>(),
            data.pop<bool>(),
            data.pop<bool>(),
            PropertyDecode(tag_v<std::string>, data)
        };
    }

    inline AnimationList PropertyDecode(tag<AnimationList>, PropertyBasicView& data) {
        size_t n = data.pop<uint8_t>();
        AnimationList t;
        t.reserve(n);
        for (size_t i = 0; i < n; ++i) {
            t.emplace_back(PropertyDecode(tag_v<Animation>, data));
        }
        return t;
    }
}
