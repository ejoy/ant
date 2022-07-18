#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

#include "lua.hpp"

#include "lua2struct.h"
#include "luabgfx.h"
#include <bgfx/c99/bgfx.h>
#include <cstdint>
#include <cassert>

static int
lnew_render_object(lua_State *L){
    //auto ro = (struct render_object*)lua_newuserdatauv(L, sizeof(render_object), 0);
    return 1;
}


extern "C" int
luaopen_render(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ nullptr, nullptr },
	};
	luaL_newlib(L, l);
	return 1;
}