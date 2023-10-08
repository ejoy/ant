#pragma once

#include <bee/nonstd/unreachable.h>

#include <functional>
#include <limits>
#include <tuple>

namespace luadebug {

    struct NoopConstructorTag {};
    template <std::size_t I>
    struct EmplaceTag {};

    template <typename... T>
    union VariantUnion;

    template <>
    union VariantUnion<> {
        constexpr explicit VariantUnion(NoopConstructorTag) noexcept {}
    };

    template <typename Head, typename... Tail>
    union VariantUnion<Head, Tail...> {
        using TailUnion = VariantUnion<Tail...>;
        explicit constexpr VariantUnion(NoopConstructorTag) noexcept
            : tail(NoopConstructorTag()) {}
        template <typename... T>
        explicit constexpr VariantUnion(EmplaceTag<0>, T&&... args)
            : head(std::forward<T>(args)...) {}
        template <std::size_t I, typename... T>
        explicit constexpr VariantUnion(EmplaceTag<I>, T&&... args)
            : tail(EmplaceTag<I - 1> {}, std::forward<T>(args)...) {}
        Head head;
        TailUnion tail;
    };

    template <std::size_t I, typename T, typename... Ts>
    constexpr std::size_t VariantIndexImpl() {
        static_assert(sizeof...(Ts) > I, "Type not found in variant");
        if constexpr (I == sizeof...(Ts)) {
            return I;
        }
        else if constexpr (std::is_same_v<std::tuple_element_t<I, std::tuple<Ts...>>, T>) {
            return I;
        }
        else {
            return VariantIndexImpl<I + 1, T, Ts...>();
        }
    }
    template <typename T, typename... Ts>
    constexpr std::size_t VariantIndex = VariantIndexImpl<0, T, Ts...>();

    template <typename... Ts>
    struct variant {
        using IndexType = signed char;
        static_assert(sizeof...(Ts) < static_cast<size_t>((std::numeric_limits<IndexType>::max)()));
        static constexpr auto npos = static_cast<IndexType>(-1);

        VariantUnion<Ts...> storage_;
        IndexType index_;

        constexpr variant()      = default;
        variant(variant&& other) = default;

        template <typename T>
        constexpr variant(T&& t)
            : storage_(EmplaceTag<VariantIndex<T, Ts...>>(), std::forward<T>(t))
            , index_(VariantIndex<T, Ts...>) {}

        constexpr std::size_t index() const noexcept {
            return static_cast<std::size_t>(index_);
        }

        auto& Storage() noexcept {
            return storage_;
        }

        auto const& Storage() const noexcept {
            return storage_;
        }
    };

    template <typename T>
    struct variant_size;
    template <typename... Ts>
    struct variant_size<variant<Ts...>>
        : std::integral_constant<std::size_t, sizeof...(Ts)> {};
    template <typename T>
    struct variant_size<const T> : variant_size<T>::type {};
    template <typename T>
    struct variant_size<volatile T> : variant_size<T>::type {};
    template <typename T>
    struct variant_size<const volatile T> : variant_size<T>::type {};
    template <typename T>
    constexpr std::size_t variant_size_v = variant_size<T>::value;

    template <std::size_t I, typename Variant>
    struct VariantAccessResultImpl;
    template <std::size_t I, template <typename...> typename Variantemplate, typename... T>
    struct VariantAccessResultImpl<I, Variantemplate<T...>&> {
        using type = typename std::tuple_element_t<I, std::tuple<T...>>&;
    };
    template <std::size_t I, template <typename...> typename Variantemplate, typename... T>
    struct VariantAccessResultImpl<I, const Variantemplate<T...>&> {
        using type = const typename std::tuple_element_t<I, std::tuple<T...>>&;
    };
    template <std::size_t I, template <typename...> typename Variantemplate, typename... T>
    struct VariantAccessResultImpl<I, Variantemplate<T...>&&> {
        using type = typename std::tuple_element_t<I, std::tuple<T...>>&&;
    };
    template <std::size_t I, template <typename...> typename Variantemplate, typename... T>
    struct VariantAccessResultImpl<I, const Variantemplate<T...>&&> {
        using type = const typename std::tuple_element_t<I, std::tuple<T...>>&&;
    };
    template <std::size_t I, typename Variant>
    using VariantAccessResult = typename VariantAccessResultImpl<I, Variant&&>::type;
    template <typename Visitor, typename Variant>
    struct VisitResultImpl {
        using type = std::invoke_result_t<Visitor, VariantAccessResult<0, Variant>>;
    };
    template <typename Visitor, typename Variant>
    using VisitResult = typename VisitResultImpl<Visitor, Variant>::type;

    template <std::size_t I, typename Variant>
    inline VariantAccessResult<I, Variant> VariantAccess(Variant&& var) {
        return reinterpret_cast<VariantAccessResult<I, Variant>>(var.Storage());
    }

    template <std::size_t I, std::size_t EndIndex>
    struct SwitchCase {
        template <typename Visitor, typename Variant>
        static VisitResult<Visitor, Variant> Run(Visitor&& vis, Variant&& var) {
            if constexpr (I < EndIndex) {
                return std::invoke(std::forward<Visitor>(vis), VariantAccess<I>(std::forward<Variant>(var)));
            }
            else {
                std::unreachable();
            }
        }
    };
    template <typename Visitor, typename Variant>
    VisitResult<Visitor, Variant> visit(Visitor&& vis, Variant&& var) {
        constexpr static std::size_t EndIndex = variant_size_v<std::remove_reference_t<Variant>>;
        static_assert(EndIndex <= 16);
        switch (var.index()) {
        case 0:
            return SwitchCase<0, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 1:
            return SwitchCase<1, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 2:
            return SwitchCase<2, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 3:
            return SwitchCase<3, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 4:
            return SwitchCase<4, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 5:
            return SwitchCase<5, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 6:
            return SwitchCase<6, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 7:
            return SwitchCase<7, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 8:
            return SwitchCase<8, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 9:
            return SwitchCase<9, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 10:
            return SwitchCase<10, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 11:
            return SwitchCase<11, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 12:
            return SwitchCase<12, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 13:
            return SwitchCase<13, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 14:
            return SwitchCase<14, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        case 15:
            return SwitchCase<15, EndIndex>::Run(std::forward<Visitor>(vis), std::forward<Variant>(var));
        default:
            std::unreachable();
        }
    }
}
