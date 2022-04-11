#include "pch.h"

#include <core/Interface.h>
#include <core/Document.h>
#include <core/Stream.h>
#include <core/Event.h>
#include <core/EventListener.h>

extern "C" {
#include <lua.h>
#include "lauxlib.h"
#include "lualib.h"
}

#include "luaplugin.h"
#include "luabind.h"

class lua_plugin;

class lua_event_listener final : public Rml::EventListener {
public:
	lua_event_listener(lua_plugin* p, Rml::Element* element, const std::string& type, const std::string& code, bool use_capture);
	~lua_event_listener();
private:
	void OnDetach(Rml::Element* element) override;
	void ProcessEvent(Rml::Event& event) override;
	lua_plugin *plugin;
};

static int ref_function(luaref reference, lua_State* L, const char* funcname) {
	if (lua_getfield(L, -1, funcname) != LUA_TFUNCTION) {
		luaL_error(L, "Missing %s", funcname);
	}
	return luaref_ref(reference, L);
}

lua_plugin::~lua_plugin() {
	luaref_close(reference);
}

Rml::EventListener* lua_plugin::OnCreateEventListener(Rml::Element* element, const std::string& type, const std::string& code, bool use_capture) {
	return new lua_event_listener(this, element, type, code, use_capture);
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

void lua_plugin::register_event(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_settop(L, 1);
	reference = luaref_init(L);
	ref_function(reference, L, "OnLoadInlineScript");
	ref_function(reference, L, "OnLoadExternalScript");
	ref_function(reference, L, "OnCreateElement");
	ref_function(reference, L, "OnEvent");
	ref_function(reference, L, "OnEventAttach");
	ref_function(reference, L, "OnEventDetach");
	ref_function(reference, L, "OnOpenFile");
}

int  lua_plugin::ref(lua_State* L) {
	return luaref_ref(reference, L);
}

void lua_plugin::unref(int ref) {
	luaref_unref(reference, ref);
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

lua_event_listener::lua_event_listener(lua_plugin* p, Rml::Element* element, const std::string& type, const std::string& code, bool use_capture)
	: Rml::EventListener(type, use_capture)
	, plugin(p)
	{
	luabind::invoke([&](lua_State* L) {
		Rml::Document* doc = element->GetOwnerDocument();
		lua_pushlightuserdata(L, (void*)this);
		lua_pushlightuserdata(L, (void*)doc);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, code.c_str(), code.length());
		plugin->call(L, LuaEvent::OnEventAttach, 4);
	});
}

lua_event_listener::~lua_event_listener() {
	// element should be the same with Init
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)this);
		plugin->call(L, LuaEvent::OnEventDetach, 1);
	});
}

void lua_event_listener::ProcessEvent(Rml::Event& event) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)this);
		plugin->pushevent(L, event);
		plugin->call(L, LuaEvent::OnEvent, 2);
	});
}

void lua_event_listener::OnDetach(Rml::Element* element) {
	delete this;
}
