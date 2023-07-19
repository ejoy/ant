#include <core/Core.h>
#include <core/Interface.h>
#include <core/Document.h>
#include <util/Stream.h>
#include <core/Event.h>
#include <binding/luaplugin.h>
#include <binding/luabind.h>
#include "lua2struct.h"
extern "C" {
#include <lua.h>
#include "lauxlib.h"
#include "lualib.h"
}


static uint32_t
border_color_or_compare(char c){
	int n = 0;
	if(c >= '0' && c <= '9'){
		n = c - '0';
	}else if(c >= 'a' && c <= 'f'){
		n = c - 'a' + 10 ;
	}
	return n;
}

class lua_plugin;

static int ref_function(luaref reference, lua_State* L, const char* funcname) {
	if (lua_getfield(L, -1, funcname) != LUA_TFUNCTION) {
		luaL_error(L, "Missing %s", funcname);
	}
	return luaref_ref(reference, L);
}

lua_plugin::lua_plugin(lua_State* L) {
	register_event(L);
	Rml::SetPlugin(this);
}

lua_plugin::~lua_plugin() {
	luaref_close(reference);
}

void lua_plugin::OnLoadInlineScript(Rml::Document* document, const std::string& content, const std::string& source_path, int source_line) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlstring(L, content.data(), content.size());
		lua_pushlstring(L, source_path.data(), source_path.size());
		lua_pushinteger(L, source_line);
		call(L, LuaEvent::OnLoadInlineScript, 4);
	});
}

void lua_plugin::OnLoadExternalScript(Rml::Document* document, const std::string& source_path) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlstring(L, source_path.data(), source_path.size());
		call(L, LuaEvent::OnLoadExternalScript, 2);
	});
}

void lua_plugin::OnCreateElement(Rml::Document* document, Rml::Element* element, const std::string& tag) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, tag.data(), tag.size());
		call(L, LuaEvent::OnCreateElement, 3);
	});
}

void lua_plugin::OnCreateText(Rml::Document* document, Rml::Text* text) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)text);
		call(L, LuaEvent::OnCreateText, 2);
	});
}

void lua_plugin::OnUpdateDataModel(Rml::Document* document) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		call(L, LuaEvent::OnUpdateDataModel, 1);
	});
}

void lua_plugin::OnDispatchEvent(Rml::Document* document, Rml::Element* element, const std::string& type, const luavalue::table& eventData) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, type.data(), type.size());
		luavalue::get(L, eventData);
		call(L, LuaEvent::OnDispatchEvent, 4);
	});
}

void lua_plugin::OnDestroyNode(Rml::Document* document, Rml::Node* node) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)node);
		call(L, LuaEvent::OnDestroyNode, 2);
	});
}

std::string lua_plugin::OnRealPath(const std::string& path) {
    std::string res;
    luabind::invoke([&](lua_State* L) {
        lua_pushlstring(L, path.data(), path.size());
        call(L, LuaEvent::OnRealPath, 1, 1);
        if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
            res.assign(str, sz);
        }
    });
    return res;
}

void lua_plugin::OnLoadTexture(Rml::Document* document, Rml::Element* element, const std::string& path) {
    luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
        lua_pushlstring(L, path.data(), path.size());
		lua_pushnumber(L, 0);
		lua_pushnumber(L, 0);
		lua_pushboolean(L, false);
        call(L, LuaEvent::OnLoadTexture, 6, 0);
    });
}

void lua_plugin::OnLoadTexture(Rml::Document* document, Rml::Element* element, const std::string& path, Rml::Size size) {
    luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
        lua_pushlstring(L, path.data(), path.size());
		lua_pushnumber(L, size.w);
		lua_pushnumber(L, size.h);
		lua_pushboolean(L, true);
        call(L, LuaEvent::OnLoadTexture, 6, 0);
    });
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
void lua_plugin::OnParseText(const std::string& str,std::vector<Rml::group>& groups,std::vector<int>& groupMap,std::vector<Rml::image>& images,std::vector<int>& imageMap,std::string& ctext,Rml::group& default_group) {
    luabind::invoke([&](lua_State* L) {
        lua_pushstring(L, str.data());
		call(L, LuaEvent::OnParseText, 1, 5);

		//-1 -2 -3 -4 -5 - imagemap images groupmap groups ctext

		lua_pushnil(L);//-1 -2 - nil imagemap
		while(lua_next(L,-2)){//-1 -2 idx imagemap
			imageMap.emplace_back((int)lua_tointeger(L,-1)-1);
			lua_pop(L,1);
		}
		lua_pop(L,1);

		lua_pushnil(L);
		while(lua_next(L,-2)){
			Rml::image image;
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
			Rml::group group;
			lua_getfield(L,-1,"color");
			size_t sz=0;
			const char* s = lua_tolstring(L, -1, &sz);
			std::string str(s,sz);
			if(str=="default"){
				group.color=default_group.color;
			}
			else{
				Rml::Color c;
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

void lua_plugin::register_event(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_settop(L, 1);
	lua_getfield(L, 1, "callback");
	lua_remove(L, 1);
	luaL_checktype(L, 1, LUA_TTABLE);
	reference = luaref_init(L);
	ref_function(reference, L, "OnLoadInlineScript");
	ref_function(reference, L, "OnLoadExternalScript");
	ref_function(reference, L, "OnCreateElement");
	ref_function(reference, L, "OnCreateText");
	ref_function(reference, L, "OnUpdateDataModel");
	ref_function(reference, L, "OnDispatchEvent");
	ref_function(reference, L, "OnDestroyNode");
	ref_function(reference, L, "OnRealPath");
	ref_function(reference, L, "OnLoadTexture");
	ref_function(reference, L, "OnParseText");
}

luaref_box lua_plugin::ref(lua_State* L) {
	luaref_box box {reference, L};
	assert(box.isvalid());
	return box;
}

void lua_plugin::callref(lua_State* L, int ref, size_t argn, size_t retn) {
	luaref_get(reference, L, ref);
	lua_insert(L, -1 - (int)argn);
	lua_call(L, (int)argn, (int)retn);
}

void lua_plugin::call(lua_State* L, LuaEvent eid, size_t argn, size_t retn) {
	callref(L, (int)eid, argn, retn);
}

void lua_plugin::pushevent(lua_State* L, const Rml::Event& event) {
	luaref_get(reference, L, event.GetParameters());
	luaL_checktype(L, -1, LUA_TTABLE);
	lua_pushstring(L, event.GetType().c_str());
	lua_setfield(L, -2, "type");
	Rml::Element* target = event.GetTargetElement();
	target? lua_pushlightuserdata(L, target): lua_pushnil(L);
	lua_setfield(L, -2, "target");
	Rml::Element* current = event.GetCurrentElement();
	current ? lua_pushlightuserdata(L, current) : lua_pushnil(L);
	lua_setfield(L, -2, "current");
}

