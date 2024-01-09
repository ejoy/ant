#pragma once

#define ENUM_FLAG_OPERATORS(name)                                     \
    constexpr name operator~(name a) {                                \
        return static_cast<name>(                                     \
            ~static_cast<std::underlying_type<name>::type>(a));       \
    }                                                                 \
    constexpr name operator|(name a, name b) {                        \
        return static_cast<name>(                                     \
            static_cast<std::underlying_type<name>::type>(a) |        \
            static_cast<std::underlying_type<name>::type>(b));        \
    }                                                                 \
    constexpr name operator&(name a, name b) {                        \
        return static_cast<name>(                                     \
            static_cast<std::underlying_type<name>::type>(a) &        \
            static_cast<std::underlying_type<name>::type>(b));        \
    }                                                                 \
    constexpr name operator^(name a, name b) {                        \
        return static_cast<name>(                                     \
            static_cast<std::underlying_type<name>::type>(a) ^        \
            static_cast<std::underlying_type<name>::type>(b));        \
    }                                                                 \
    inline name& operator|=(name& a, name b) {                        \
        return reinterpret_cast<name&>(                               \
            reinterpret_cast<std::underlying_type<name>::type&>(a) |= \
            static_cast<std::underlying_type<name>::type>(b));        \
    }                                                                 \
    inline name& operator&=(name& a, name b) {                        \
        return reinterpret_cast<name&>(                               \
            reinterpret_cast<std::underlying_type<name>::type&>(a) &= \
            static_cast<std::underlying_type<name>::type>(b));        \
    }                                                                 \
    inline name& operator^=(name& a, name b) {                        \
        return reinterpret_cast<name&>(                               \
            reinterpret_cast<std::underlying_type<name>::type&>(a) ^= \
            static_cast<std::underlying_type<name>::type>(b));        \
    }
