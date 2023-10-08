#pragma once

#include <bee/nonstd/bit.h>
#include <bee/nonstd/to_underlying.h>
#include <bee/nonstd/unreachable.h>
#include <bee/utility/zstring_view.h>

#include <stdexcept>
#include <type_traits>

#include "rdebug_debughost.h"
#include "rdebug_lua.h"

namespace luadebug {
    struct protected_area {
        int raise_error(const char* msg) {
            leave();
            luadbg_pushstring(L, msg);
            return luadbg_error(L);
        }

        inline void check_type(luadbg_State*, int arg, int t) {
            if (luadbg_type(L, arg) != t) {
                leave();
                luadbgL_typeerror(L, arg, luadbg_typename(L, t));
            }
        }

        template <typename T, typename I>
        inline constexpr bool checklimit(I i) {
            static_assert(std::is_integral_v<I>);
            static_assert(std::is_integral_v<T>);
            static_assert(sizeof(I) >= sizeof(T));
            if constexpr (sizeof(I) == sizeof(T)) {
                return true;
            }
            else if constexpr (std::numeric_limits<I>::is_signed == std::numeric_limits<T>::is_signed) {
                return i >= std::numeric_limits<T>::lowest() && i <= (std::numeric_limits<T>::max)();
            }
            else if constexpr (std::numeric_limits<I>::is_signed) {
                return static_cast<std::make_unsigned_t<I>>(i) >= std::numeric_limits<T>::lowest() && static_cast<std::make_unsigned_t<I>>(i) <= (std::numeric_limits<T>::max)();
            }
            else {
                return static_cast<std::make_signed_t<I>>(i) >= std::numeric_limits<T>::lowest() && static_cast<std::make_signed_t<I>>(i) <= (std::numeric_limits<T>::max)();
            }
        }

        template <typename T>
        inline T checkinteger(luadbg_State*, int arg) {
            static_assert(std::is_trivial_v<T>);
            if constexpr (std::is_enum_v<T>) {
                using UT = std::underlying_type_t<T>;
                return static_cast<T>(checkinteger<UT>(L, arg));
            }
            else if constexpr (sizeof(T) != sizeof(luadbg_Integer)) {
                static_assert(std::is_integral_v<T>);
                static_assert(sizeof(T) < sizeof(luadbg_Integer));
                luadbg_Integer r = checkinteger<luadbg_Integer>(L, arg);
                if (checklimit<T>(r)) {
                    return static_cast<T>(r);
                }
                leave();
                luadbgL_error(L, "bad argument '#%d' limit exceeded", arg);
                std::unreachable();
            }
            else if constexpr (!std::is_same_v<T, luadbg_Integer>) {
                return std::bit_cast<T>(checkinteger<luadbg_Integer>(L, arg));
            }
            else {
                int isnum;
                luadbg_Integer d = luadbg_tointegerx(L, arg, &isnum);
                if (!isnum) {
                    leave();
                    if (luadbg_isnumber(L, arg))
                        luadbgL_argerror(L, arg, "number has no integer representation");
                    else
                        luadbgL_typeerror(L, arg, luadbg_typename(L, LUA_TNUMBER));
                }
                return d;
            }
        }

        template <typename T>
        T optinteger(luadbg_State*, int arg, T def) {
            static_assert(std::is_trivial_v<T>);
            if constexpr (std::is_enum_v<T>) {
                using UT = std::underlying_type_t<T>;
                return static_cast<T>(optinteger<UT>(L, arg, std::to_underlying(def)));
            }
            else if constexpr (sizeof(T) != sizeof(luadbg_Integer)) {
                static_assert(std::is_integral_v<T>);
                static_assert(sizeof(T) < sizeof(luadbg_Integer));
                luadbg_Integer r = optinteger<luadbg_Integer>(L, arg, static_cast<luadbg_Integer>(def));
                if (checklimit<T>(r)) {
                    return static_cast<T>(r);
                }
                leave();
                luadbgL_error(L, "bad argument '#%d' limit exceeded", arg);
                std::unreachable();
            }
            else if constexpr (!std::is_same_v<T, luadbg_Integer>) {
                return std::bit_cast<T>(optinteger<luadbg_Integer>(L, arg, std::bit_cast<luadbg_Integer>(def)));
            }
            else {
                return luadbgL_optinteger(L, arg, def);
            }
        }

        inline bee::zstring_view checkstring(luadbg_State*, int arg) {
            size_t sz;
            const char* s = luadbg_tolstring(L, arg, &sz);
            if (!s) {
                leave();
                luadbgL_typeerror(L, arg, luadbg_typename(L, LUA_TSTRING));
            }
            return { s, sz };
        }

        void check_client_stack(int sz) {
            if (lua_checkstack(hL, sz) == 0) {
                raise_error("stack overflow");
            }
        }

        void check_host_stack(int sz) {
            if (luadbg_checkstack(L, sz) == 0) {
                raise_error("stack overflow");
            }
        }

        protected_area(luadbg_State* L)
            : L(L)
            , hL(debughost::get(L))
            , top(lua_gettop(hL)) {
            check_recursive();
        };
        ~protected_area() {
#if !defined(NDEBUG)
            if (top != lua_gettop(hL)) {
                luadbgL_error(L, "not expected");
            }
#endif
            leave();
        };
        luadbg_State* get_host() const noexcept {
            return L;
        }
        lua_State* get_client() const noexcept {
            return hL;
        }

        using visitor = int (*)(luadbg_State* L, lua_State* hL, protected_area& area);

        static inline int call(luadbg_State* L, visitor func) {
            protected_area area(L);
            lua_State* hL = area.get_client();
            try {
                int r = func(L, hL, area);
                return r;
            } catch (const std::exception& e) {
                fprintf(stderr, "catch std::exception: %s\n", e.what());
            } catch (...) {
                fprintf(stderr, "catch unknown exception\n");
            }
            area.leave();
            return 0;
        }

    private:
        luadbg_State* L;
        lua_State* hL;
        int top = -1;
        static inline int CHECK_RECURSIVE;
        inline void check_recursive() {
#if !defined(NDEBUG)
            if (luadbg_rawgetp(L, LUADBG_REGISTRYINDEX, &CHECK_RECURSIVE) != LUA_TNIL) {
                luadbgL_error(L, "can't recursive");
            }
            luadbg_pop(L, 1);
            luadbg_pushboolean(L, 1);
            luadbg_rawsetp(L, LUADBG_REGISTRYINDEX, &CHECK_RECURSIVE);
#endif
        }
        inline void leave() {
            if (top >= 0) {
#if !defined(NDEBUG)
                luadbg_pushnil(L);
                luadbg_rawsetp(L, LUADBG_REGISTRYINDEX, &CHECK_RECURSIVE);
#endif
                lua_settop(hL, top);
                top = -1;
            }
        }
    };

    template <protected_area::visitor func>
    static int protected_call(luadbg_State* L) {
        return protected_area::call(L, func);
    }
}
