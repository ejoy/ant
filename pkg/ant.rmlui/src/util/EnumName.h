#pragma once

#include <string_view>

namespace Rml {
    template <auto Value>
    constexpr auto EnumName() {
#if __GNUC__ || __clang__
        std::string_view name = __PRETTY_FUNCTION__;
        std::size_t start = name.find('=') + 2;
        std::size_t end = name.size() - 1;
        name = std::string_view{name.data() + start, end - start};
        start = name.rfind("::");
        return start == std::string_view::npos ? name : std::string_view{name.data() + start + 2, name.size() - start - 2};
#elif _MSC_VER
        std::string_view name = __FUNCSIG__;
        std::size_t start = name.find('<') + 1;
        std::size_t end = name.rfind(">(");
        name = std::string_view{name.data() + start, end - start};
        start = name.rfind("::");
        return start == std::string_view::npos ? name : std::string_view{name.data() + start + 2, name.size() - start - 2};
#else
        static_assert(false, "Unsupported compiler");
#endif
    }

    template <auto Value>
    constexpr auto EnumNameV = EnumName<Value>();
}
