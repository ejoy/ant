#pragma once

#include <utility> 
#include <lua.hpp>
#include "binding.h"

namespace ant::lua {
    template <class T>
    int convert_to_lua(lua_State* L, const T& v);

    template <class F, class S>
    int convert_to_lua(lua_State* L, const std::pair<F, S>& v) {
        int nresult = 0;
        nresult += convert_to_lua(L, v.first);
        nresult += convert_to_lua(L, v.second);
        return nresult;
    }

    template <class Iterator>
    struct iterator {
        static int next(lua_State* L) {
            LUA_TRY;
            iterator* self = static_cast<iterator*>(lua_touserdata(L, lua_upvalueindex(1)));
            if (self->first_ == self->last_) {
                lua_pushnil(L);
                return 1;
            }
            int nreslut = convert_to_lua(L, *self->first_);
            ++(self->first_);
            return nreslut;
            LUA_TRY_END;
        }
        static int destroy(lua_State* L) {
            static_cast<iterator*>(lua_touserdata(L, 1))->~iterator();
            return 0;
        }
        iterator(const Iterator& first, const Iterator& last)
            : first_(first)
            , last_(last)
        { }
        Iterator first_;
        Iterator last_;
    };

    template <class Iterator>
    int make_range(lua_State* L, const Iterator& first, const Iterator& last) {
        void* storage = lua_newuserdata(L, sizeof(iterator<Iterator>));
        lua_newtable(L);
        lua_pushcclosure(L, iterator<Iterator>::destroy, 0);
        lua_setfield(L, -2, "__gc");
        lua_setmetatable(L, -2);
        lua_pushcclosure(L, iterator<Iterator>::next, 1);
        new (storage) iterator<Iterator>(first, last);
        return 1;
    }

    template <class Container>
    int make_range(lua_State* L, const Container& container) {
        return make_range(L, std::begin(container), std::end(container));
    }
}
