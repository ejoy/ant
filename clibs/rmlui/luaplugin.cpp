#include "pch.h"

#include <RmlUi/Plugin.h>
#include <RmlUi/Document.h>
#include <RmlUi/Stream.h>
#include <RmlUi/EventListener.h>
#include <RmlUi/EventListenerInstancer.h>
#include <RmlUi/Factory.h>

extern "C" {
#include "lua.h"
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

class lua_event_listener_instancer : public Rml::EventListenerInstancer {
public:
	lua_event_listener_instancer(lua_plugin *p) : plugin(p) {}
private:
	Rml::EventListener* InstanceEventListener(Rml::Element* element, const std::string& type, const std::string& code, bool use_capture) override {
		return new lua_event_listener(plugin, element, type, code, use_capture);
	}
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

void lua_plugin::OnInitialise() {
	event_listener_instancer = new lua_event_listener_instancer(this);
	Rml::Factory::RegisterEventListenerInstancer(event_listener_instancer);
}

void lua_plugin::OnShutdown() {
	delete this;
}

void lua_plugin::OnDocumentCreate(Rml::Document* document) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		call(L, LuaEvent::OnDocumentCreate, 1);
	});
}

void lua_plugin::OnDocumentDestroy(Rml::Document* document) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		call(L, LuaEvent::OnDocumentDestroy, 1);
	});
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

void lua_plugin::register_event(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_settop(L, 1);
	reference = luaref_init(L);
	ref_function(reference, L, "OnDocumentCreate");
	ref_function(reference, L, "OnDocumentDestroy");
	ref_function(reference, L, "OnLoadInlineScript");
	ref_function(reference, L, "OnLoadExternalScript");
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
		lua_pushevent(L, event);
		plugin->call(L, LuaEvent::OnEvent, 2);
	});
}

void lua_event_listener::OnDetach(Rml::Element* element) {
	delete this;
}
