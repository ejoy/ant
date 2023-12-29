#include <binding/Context.h>
#include <core/Interface.h>
#include <core/Document.h>
#include <core/Event.h>
#include <binding/ScriptImpl.h>
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
	Rml::Rect unpack<Rml::Rect>(lua_State* L, int idx) {
		luaL_checktype(L, idx, LUA_TTABLE);
		lua_getfield(L, idx, "x");
		float x = lua_struct::unpack<float>(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, idx, "y");
		float y = lua_struct::unpack<float>(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, idx, "w");
		float w = lua_struct::unpack<float>(L, -1);
		lua_pop(L, 1);
		lua_getfield(L, idx, "h");
		float h = lua_struct::unpack<float>(L, -1);
		lua_pop(L, 1);
		return Rml::Rect(x, y, w, h);
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

ScriptImpl::ScriptImpl(lua_State* L) {
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

ScriptImpl::~ScriptImpl() {
	luaref_close(reference);
}

void ScriptImpl::OnCreateElement(Document* document, Element* element, const std::string& tag) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, tag.data(), tag.size());
		CallLua(L, reference, LuaEvent::OnCreateElement, 3);
	});
}

void ScriptImpl::OnCreateText(Document* document, Text* text) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)text);
		CallLua(L, reference, LuaEvent::OnCreateText, 2);
	});
}

void ScriptImpl::OnDispatchEvent(Document* document, Element* element, const std::string& type, const luavalue::table& eventData) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, type.data(), type.size());
		luavalue::get(L, eventData);
		CallLua(L, reference, LuaEvent::OnDispatchEvent, 4);
	});
}

void ScriptImpl::OnDestroyNode(Document* document, Node* node) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)node);
		CallLua(L, reference, LuaEvent::OnDestroyNode, 2);
	});
}

void ScriptImpl::OnLoadTexture(Document* document, Element* element, const std::string& path) {
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

void ScriptImpl::OnLoadTexture(Document* document, Element* element, const std::string& path, Size size) {
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

void ScriptImpl::OnParseText(const std::string& str,std::vector<group>& groups,std::vector<int>& groupMap,std::vector<image>& images,std::vector<int>& imageMap,std::string& ctext,group& default_group) {
    luabind::invoke([&](lua_State* L) {
        lua_pushstring(L, str.data());
		CallLua(L, reference, LuaEvent::OnParseText, 1, 5);

		//-1 -2 -3 -4 -5 - imagemap images groupmap groups ctext
		
		imageMap = lua_struct::unpack<std::remove_cvref_t<decltype(imageMap)>>(L, -1);
		lua_pop(L, 1);

		images = lua_struct::unpack<std::remove_cvref_t<decltype(images)>>(L, -1);
		lua_pop(L, 1);


		groupMap = lua_struct::unpack<std::remove_cvref_t<decltype(groupMap)>>(L, -1);
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
