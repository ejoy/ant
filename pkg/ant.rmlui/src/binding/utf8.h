#pragma once

#include <array>
#include <iterator>
#include <string_view>
#include <stdint.h>

namespace utf8 {
    const uint16_t LEAD_SURROGATE_MIN  = 0xd800u;
    const uint16_t LEAD_SURROGATE_MAX  = 0xdbffu;
    const uint16_t TRAIL_SURROGATE_MIN = 0xdc00u;
    const uint16_t TRAIL_SURROGATE_MAX = 0xdfffu;
    const uint16_t LEAD_OFFSET         = 0xd7c0u;
    const uint32_t SURROGATE_OFFSET    = 0xfca02400u;
    const uint32_t CODE_POINT_MAX      = 0x0010ffffu;

    template <typename octet_type>
    inline uint8_t mask8(octet_type oc) {
        return static_cast<uint8_t>(0xff & oc);
    }

    template <typename octet_type>
    inline bool is_trail(octet_type oc) {
        return ((mask8(oc) >> 6) == 0x2);
    }

    inline bool is_lead_surrogate(uint16_t cp) {
        return (cp >= LEAD_SURROGATE_MIN && cp <= LEAD_SURROGATE_MAX);
    }

    inline bool is_trail_surrogate(uint16_t cp) {
        return (cp >= TRAIL_SURROGATE_MIN && cp <= TRAIL_SURROGATE_MAX);
    }

    inline bool is_surrogate(uint16_t cp) {
        return (cp >= LEAD_SURROGATE_MIN && cp <= TRAIL_SURROGATE_MAX);
    }

    inline bool is_code_point_valid(uint32_t cp) {
        return (cp <= CODE_POINT_MAX && !is_surrogate(cp));
    }

    template <typename octet_iterator>
    inline int sequence_length(octet_iterator lead_it) {
        uint8_t lead = mask8(*lead_it);
        if (lead < 0x80)
            return 1;
        else if ((lead >> 5) == 0x6)
            return 2;
        else if ((lead >> 4) == 0xe)
            return 3;
        else if ((lead >> 3) == 0x1e)
            return 4;
        else
            return 0;
    }

    inline bool is_overlong_sequence(uint32_t cp, int length) {
        if (cp < 0x80) {
            if (length != 1) 
                return true;
        }
        else if (cp < 0x800) {
            if (length != 2) 
                return true;
        }
        else if (cp < 0x10000) {
            if (length != 3) 
                return true;
        }
        return false;
    }

    enum class error {
        SUCCESS,
        NOT_ENOUGH_ROOM,
        INVALID_LEAD,
        INCOMPLETE_SEQUENCE,
        OVERLONG_SEQUENCE,
        INVALID_CODE_POINT,
    };

    template <typename octet_iterator>
    error get_sequence_1(octet_iterator& it, octet_iterator end, uint32_t& code_point) {
        if (it == end) return error::NOT_ENOUGH_ROOM;
        code_point = mask8(*it);
        return error::SUCCESS;
    }

    template <typename octet_iterator>
    error get_sequence_2(octet_iterator& it, octet_iterator end, uint32_t& code_point) {
        if (it == end) return error::NOT_ENOUGH_ROOM;
        code_point = mask8(*it);
        if (++it == end) return error::NOT_ENOUGH_ROOM;
        if (!is_trail(*it)) return error::INCOMPLETE_SEQUENCE;
        code_point = ((code_point << 6) & 0x7ff) + ((*it) & 0x3f);
        return error::SUCCESS;
    }

    template <typename octet_iterator>
    error get_sequence_3(octet_iterator& it, octet_iterator end, uint32_t& code_point) {
        if (it == end) return error::NOT_ENOUGH_ROOM;
        code_point = mask8(*it);
        if (++it == end) return error::NOT_ENOUGH_ROOM;
        if (!is_trail(*it)) return error::INCOMPLETE_SEQUENCE;
        code_point = ((code_point << 12) & 0xffff) + ((mask8(*it) << 6) & 0xfff);
        if (++it == end) return error::NOT_ENOUGH_ROOM;
        if (!is_trail(*it)) return error::INCOMPLETE_SEQUENCE;
        code_point += (*it) & 0x3f;
        return error::SUCCESS;
    }

    template <typename octet_iterator>
    error get_sequence_4(octet_iterator& it, octet_iterator end, uint32_t& code_point) {
        if (it == end) return error::NOT_ENOUGH_ROOM;
        code_point = mask8(*it);
        if (++it == end) return error::NOT_ENOUGH_ROOM;
        if (!is_trail(*it)) return error::INCOMPLETE_SEQUENCE;
        code_point = ((code_point << 18) & 0x1fffff) + ((mask8(*it) << 12) & 0x3ffff);
        if (++it == end) return error::NOT_ENOUGH_ROOM;
        if (!is_trail(*it)) return error::INCOMPLETE_SEQUENCE;
        code_point += (mask8(*it) << 6) & 0xfff;
        if (++it == end) return error::NOT_ENOUGH_ROOM;
        if (!is_trail(*it)) return error::INCOMPLETE_SEQUENCE;
        code_point += (*it) & 0x3f;
        return error::SUCCESS;
    }

    template <typename octet_iterator>
    error validate_next(octet_iterator& it, octet_iterator end, uint32_t& codepoint) {
        if (it == end)
            return error::NOT_ENOUGH_ROOM;
        octet_iterator original_it = it;
        uint32_t cp = 0;
        const auto length = sequence_length(it);
        error err = error::SUCCESS;
        switch (length) {
        case 0: return error::INVALID_LEAD;
        case 1: err = get_sequence_1(it, end, cp); break;
        case 2: err = get_sequence_2(it, end, cp); break;
        case 3: err = get_sequence_3(it, end, cp); break;
        case 4: err = get_sequence_4(it, end, cp); break;
        }

        if (err == error::SUCCESS) {
            if (is_code_point_valid(cp)) {
                if (!is_overlong_sequence(cp, length)){
                    ++it;
                    codepoint = cp;
                    return error::SUCCESS;
                }
                else
                    err = error::OVERLONG_SEQUENCE;
            }
            else 
                err = error::INVALID_CODE_POINT;
        }
        it = original_it;
        return err;
    }

    template <typename T>
    class view {
    public:
        using octet_iterator = typename T::const_iterator;
        class const_iterator {
        public:
            using iterator_category = std::forward_iterator_tag;
            explicit const_iterator(octet_iterator iter, octet_iterator end, uint32_t replacement)
                : iter { iter }
                , end { end }
                , replacement { replacement }
            {}
            const_iterator operator++() {
                iter = next;
                return *this;
            }
            T value() const {
                return T(iter, next);
            }
            size_t size() const {
                return next - iter;
            }
            uint32_t operator*() {
                seek();
                return codepoint;
            }
            bool operator==(const const_iterator& rhs) const {
                return iter == rhs.iter;
            }
            bool operator!=(const const_iterator& rhs) const {
                return !operator==(rhs);
            }
        protected:
            void seek() {
                codepoint = 0;
                next = iter;
                switch (validate_next(next, end, codepoint)) {
                case error::SUCCESS:
                    return;
                case error::NOT_ENOUGH_ROOM:
                    codepoint = replacement;
                    next = end;
                    break;
                case error::INVALID_LEAD:
                    codepoint = replacement;
                    next = iter;
                    ++next;
                    break;
                case error::INCOMPLETE_SEQUENCE:
                case error::OVERLONG_SEQUENCE:
                case error::INVALID_CODE_POINT:
                    codepoint = replacement;
                    next = iter;
                    ++next;
                    while (next != end && is_trail(*next))
                        ++next;
                    break;
                }
            }
            octet_iterator iter;
            octet_iterator end;
            octet_iterator next;
            uint32_t codepoint = 0;
            uint32_t replacement;
        };

        view(const T& s, uint32_t replacement = 0xfffd)
            : s {s}
            , first(std::cbegin(s))
            , last(std::cend(s))
            , replacement {replacement}
        {}

        view(const T& s, size_t offset, uint32_t replacement = 0xfffd)
            : s {s}
            , first(std::cbegin(s) + offset)
            , last(std::cend(s))
            , replacement {replacement}
        {}

        const_iterator begin() const {
            return const_iterator {first, last, replacement};
        }

        const_iterator end() const {
            return const_iterator {last, last, replacement};
        }

        const T& s;
        typename T::const_iterator first;
        typename T::const_iterator last;
        uint32_t replacement;
    };

    constexpr inline std::array<char, 7> toutf8_array(uint32_t codepoint) {
        if (codepoint < 0x80) {
            return {
                (char)(uint8_t)codepoint
            };
        }
        else if (codepoint < 0x800) {
            return {
                (char)(uint8_t)(0xC0 | (codepoint << 21 >> 27)),
                (char)(uint8_t)(0x80 | (codepoint << 26 >> 26))
            };
        }
        else if (codepoint < 0x10000) {
            return {
                (char)(uint8_t)(0xE0 | (codepoint << 16 >> 28)),
                (char)(uint8_t)(0x80 | (codepoint << 20 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 26 >> 26))
            };
        }
        else if (codepoint < 0x200000) {
            return {
                (char)(uint8_t)(0xF0 | (codepoint << 11 >> 29)),
                (char)(uint8_t)(0x80 | (codepoint << 14 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 20 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 26 >> 26))
            };
        }
        else if (codepoint < 0x4000000) {
            return {
                (char)(uint8_t)(0xF8 | (codepoint << 6 >> 30)),
                (char)(uint8_t)(0x80 | (codepoint << 8 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 14 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 20 >> 26)) ,
                (char)(uint8_t)(0x80 | (codepoint << 26 >> 26))
            };
        }
        else {
            return {
                (char)(uint8_t)(0xFC | (codepoint << 1 >> 31)),
                (char)(uint8_t)(0x80 | (codepoint << 2 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 8 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 14 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 20 >> 26)),
                (char)(uint8_t)(0x80 | (codepoint << 26 >> 26))
            };
        }
    }

    template <auto Data>
    constexpr auto const& make_it_static() {
        return Data;
    }

    template <uint32_t codepoint>
    consteval auto toutf8() {
        constexpr auto const& data = make_it_static<toutf8_array(codepoint)>();
        for (size_t i = 0; i < data.size(); ++i) {
            if (data[i] == 0) {
                return std::string_view { data.data(), i - 1 };
            }
        }
        return std::string_view { data.data(), data.size() };
    }
}
