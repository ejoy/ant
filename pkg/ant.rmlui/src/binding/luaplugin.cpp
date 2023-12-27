#include <core/Core.h>
#include <core/Interface.h>
#include <core/Document.h>
#include <core/Event.h>
#include <binding/luaplugin.h>
#include "lua2struct.h"
#include <functional>

namespace luabind {
	typedef std::function<void(lua_State*)> call_t;
	typedef std::function<void(const char*)> error_t;
	inline int errhandler(lua_State* L) {
		const char* msg = lua_tostring(L, 1);
		if (msg == NULL) {
			if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING)
				return 1;
			else
				msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
		}
		luaL_traceback(L, L, msg, 1);
		return 1;
	}
	inline void errfunc(const char* msg) {
		// todo: use Rml log
		lua_writestringerror("%s\n", msg);
	}
	inline int function_call(lua_State* L) {
		call_t& f = *(call_t*)lua_touserdata(L, 1);
		f(L);
		return 0;
	}
	template <typename T>
	struct global {
		static inline T v = T();
	};
	inline void init(lua_State* L) {
		if (global<lua_State*>::v) {
			return;
		}
		global<lua_State*>::v = lua_newthread(L);
		lua_setfield(L, LUA_REGISTRYINDEX, "LUABIND_THREAD");
	}
	inline bool invoke(call_t f) {
		lua_State* L = global<lua_State*>::v;
		if (!lua_checkstack(L, 3)) {
			errfunc("stack overflow");
			return false;
		}
		lua_pushcfunction(L, errhandler);
		lua_pushcfunction(L, function_call);
		lua_pushlightuserdata(L, &f);
		int r = lua_pcall(L, 1, 0, -3);
		if (r == LUA_OK) {
			lua_pop(L, 1);
			return true;
		}
		errfunc(lua_tostring(L, -1));
		lua_pop(L, 2);
		return false;
	}
}

namespace lua_struct {
	template <>
    inline void unpack<Rml::Rect>(lua_State* L, int idx, Rml::Rect& rect, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        float x, y, w, h;
        unpack_field(L, idx, "x", x);
		unpack_field(L, idx, "y", y);
		unpack_field(L, idx, "w", w);
		unpack_field(L, idx, "h", h);
        rect = Rml::Rect(x, y, w, h);
    }
	template <>
    inline void unpack<Rml::image>(lua_State* L, int idx, Rml::image& image, void*) {
        luaL_checktype(L, idx, LUA_TTABLE);
        Rml::TextureId id;
		Rml::Rect rect;
		uint16_t width, height;
        unpack_field(L, idx, "id", id);
		lua_getfield(L,-1,"rect");
		unpack(L, idx, rect);
		lua_pop(L, 1);
		unpack_field(L, idx, "width", width);
		unpack_field(L, idx, "height", height);
        image = Rml::image(id, rect, width, height);
    }
}

namespace Rml {

enum class LuaEvent : uint8_t {
	OnCreateElement = 2,
	OnCreateText,
	OnDispatchEvent,
	OnDestroyNode,
	OnLoadTexture,
	OnParseText,
};

static int ref_function(luaref reference, lua_State* L, const char* funcname) {
	if (lua_getfield(L, -1, funcname) != LUA_TFUNCTION) {
		luaL_error(L, "Missing %s", funcname);
	}
	return luaref_ref(reference, L);
}

static void CallLua(lua_State* L, luaref reference, LuaEvent id, size_t argn, size_t retn = 0) {
	luaref_get(reference, L, (int)id);
	lua_insert(L, -1 - (int)argn);
	lua_call(L, (int)argn, (int)retn);
}

LuaPlugin::LuaPlugin(lua_State* L) {
	luabind::init(L);
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_settop(L, 1);
	lua_getfield(L, 1, "callback");
	lua_remove(L, 1);
	luaL_checktype(L, 1, LUA_TTABLE);
	reference = luaref_init(L);
	ref_function(reference, L, "OnCreateElement");
	ref_function(reference, L, "OnCreateText");
	ref_function(reference, L, "OnDispatchEvent");
	ref_function(reference, L, "OnDestroyNode");
	ref_function(reference, L, "OnLoadTexture");
	ref_function(reference, L, "OnParseText");
}

LuaPlugin::~LuaPlugin() {
	luaref_close(reference);
}

void LuaPlugin::OnCreateElement(Document* document, Element* element, const std::string& tag) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, tag.data(), tag.size());
		CallLua(L, reference, LuaEvent::OnCreateElement, 3);
	});
}

void LuaPlugin::OnCreateText(Document* document, Text* text) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)text);
		CallLua(L, reference, LuaEvent::OnCreateText, 2);
	});
}

void LuaPlugin::OnDispatchEvent(Document* document, Element* element, const std::string& type, const luavalue::table& eventData) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, type.data(), type.size());
		luavalue::get(L, eventData);
		CallLua(L, reference, LuaEvent::OnDispatchEvent, 4);
	});
}

void LuaPlugin::OnDestroyNode(Document* document, Node* node) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)node);
		CallLua(L, reference, LuaEvent::OnDestroyNode, 2);
	});
}

void LuaPlugin::OnLoadTexture(Document* document, Element* element, const std::string& path) {
    luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
        lua_pushlstring(L, path.data(), path.size());
		lua_pushnumber(L, 0);
		lua_pushnumber(L, 0);
		lua_pushboolean(L, false);
        CallLua(L, reference, LuaEvent::OnLoadTexture, 6, 0);
    });
}

void LuaPlugin::OnLoadTexture(Document* document, Element* element, const std::string& path, Size size) {
    luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
        lua_pushlstring(L, path.data(), path.size());
		lua_pushnumber(L, size.w);
		lua_pushnumber(L, size.h);
		lua_pushboolean(L, true);
        CallLua(L, reference, LuaEvent::OnLoadTexture, 6, 0);
    });
}

static uint32_t border_color_or_compare(char c){
	int n = 0;
	if(c >= '0' && c <= '9'){
		n = c - '0';
	}else if(c >= 'a' && c <= 'f'){
		n = c - 'a' + 10 ;
	}
	return n;
}

void LuaPlugin::OnParseText(const std::string& str,std::vector<group>& groups,std::vector<int>& groupMap,std::vector<image>& images,std::vector<int>& imageMap,std::string& ctext,group& default_group) {
    luabind::invoke([&](lua_State* L) {
        lua_pushstring(L, str.data());
		CallLua(L, reference, LuaEvent::OnParseText, 1, 5);

		//-1 -2 -3 -4 -5 - imagemap images groupmap groups ctext

		lua_pushnil(L);//-1 -2 - nil imagemap
		while(lua_next(L,-2)){//-1 -2 idx imagemap
			imageMap.emplace_back((int)lua_tointeger(L,-1)-1);
			lua_pop(L,1);
		}
		lua_pop(L,1);

		lua_pushnil(L);
		while(lua_next(L,-2)){
			image image;
			//id rect width height
			lua_struct::unpack(L, -1, image);
			lua_pop(L,1);
			images.emplace_back(image);
		}
		lua_pop(L,1);


		lua_pushnil(L);//-1 -2 - nil groupmap
		while(lua_next(L,-2)){//-1 -2 idx groupmap
			//float tmp_idx = (int)lua_tointeger(L,-1);
			groupMap.emplace_back((int)lua_tointeger(L,-1)-1);
			lua_pop(L,1);
		}
		lua_pop(L,1);

		lua_pushnil(L);
		while(lua_next(L,-2)){
			group group;
			lua_getfield(L,-1,"color");
			size_t sz=0;
			const char* s = lua_tolstring(L, -1, &sz);
			std::string str(s,sz);
			if(str=="default"){
				group.color=default_group.color;
			}
			else{
				Color c;
				std::string ctmp(str);
				c.r = border_color_or_compare(ctmp[0]) * 16 + border_color_or_compare(ctmp[1]);
				c.g = border_color_or_compare(ctmp[2]) * 16 + border_color_or_compare(ctmp[3]);
				c.b = border_color_or_compare(ctmp[4]) * 16 + border_color_or_compare(ctmp[5]);
				group.color = c;
			}
			lua_pop(L,1);
			lua_pop(L,1);
			groups.emplace_back(group);
		}

		lua_pop(L,1);

		if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
			std::string ctmp(str);
            ctext=str;
		}	
    });

	//TODO
}

}
