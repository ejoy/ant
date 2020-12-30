#include "pch.h"

#include <RmlUi/Plugin.h>
#include <RmlUi/ElementDocument.h>
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
	lua_event_listener(lua_plugin* p, const Rml::String& code, Rml::Element* element);
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
	Rml::EventListener* InstanceEventListener(const Rml::String& code, Rml::Element* element) override {
		return new lua_event_listener(plugin, code, element);
	}
	lua_plugin *plugin;
};

static int ref_function(luabind::reference& reference, lua_State* L, const char* funcname) {
	if (lua_getfield(L, -1, funcname) != LUA_TFUNCTION) {
		luaL_error(L, "Missing %s", funcname);
	}
	return reference.ref(L);
}

lua_plugin::~lua_plugin() {
	reference.reset();
	if (L) {
		lua_close(L);
	}
}

int lua_plugin::GetEventClasses() {
	return EVT_BASIC | EVT_DOCUMENT;
}

void lua_plugin::OnInitialise() {
	event_listener_instancer = new lua_event_listener_instancer(this);
	Rml::Factory::RegisterEventListenerInstancer(event_listener_instancer);
}

void lua_plugin::OnShutdown() {
	delete this;
}

void lua_plugin::OnDocumentCreate(Rml::ElementDocument* document) {
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)document);
		call(LuaEvent::OnDocumentCreate, 1);
	});
}

void lua_plugin::OnDocumentDestroy(Rml::ElementDocument* document) {
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)document);
		call(LuaEvent::OnDocumentDestroy, 1);
	});
}

void lua_plugin::OnLoadInlineScript(Rml::ElementDocument* document, const std::string& content, const std::string& source_path, int source_line) {
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlstring(L, content.data(), content.size());
		lua_pushlstring(L, source_path.data(), source_path.size());
		lua_pushinteger(L, source_line);
		call(LuaEvent::OnLoadInlineScript, 4);
	});
}

void lua_plugin::OnLoadExternalScript(Rml::ElementDocument* document, const std::string& source_path) {
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlstring(L, source_path.data(), source_path.size());
		call(LuaEvent::OnLoadExternalScript, 2);
	});
}

void lua_plugin::OnElementCreate(Rml::Element* element) {
}

void lua_plugin::OnElementDestroy(Rml::Element* element) {
}

bool lua_plugin::initialize(const std::string& bootstrap, std::string& errmsg) {
	L = luaL_newstate();
	if (L == NULL) {
		errmsg = "Lua VM init failed";
		return false;
	}
	auto initfunc = [&]() {	
		luaL_openlibs(L);
		luaL_requiref(L, "rmlui", lua_plugin_apis, 1);
		reference.reset(new luabind::reference(L));
		lua_pop(L, 1);
		int err = luaL_loadbuffer(L, bootstrap.data(), bootstrap.size(), bootstrap.data());
		if (err) {
			lua_error(L);
			return;
		}
		lua_call(L, 0, 1);
		if (!lua_istable(L, -1)) {
			luaL_error(L, "Init need a module table");
		}
		ref_function(*reference, L, "OnDocumentCreate");
		ref_function(*reference, L, "OnDocumentDestroy");
		ref_function(*reference, L, "OnLoadInlineScript");
		ref_function(*reference, L, "OnLoadExternalScript");
		ref_function(*reference, L, "OnEvent");
		ref_function(*reference, L, "OnEventAttach");
		ref_function(*reference, L, "OnEventDetach");
		ref_function(*reference, L, "OnUpdate");
		ref_function(*reference, L, "OnShutdown");
		ref_function(*reference, L, "OnOpenFile");
	};
	auto errfunc = [&](const char* msg) {
		errmsg = msg;
	};
	if (!luabind::invoke(L, initfunc, errfunc)) {
		lua_close(L);
		L = nullptr;
		return false;
	}
	return true;
}

int  lua_plugin::ref(lua_State* L) {
	return reference->ref(L);
}

void lua_plugin::unref(int ref) {
	reference->unref(ref);
}

void lua_plugin::callref(int ref, size_t argn, size_t retn) {
	reference->get(L, ref);
	lua_insert(L, -1 - (int)argn);
	lua_call(L, (int)argn, (int)retn);
}

void lua_plugin::call(LuaEvent eid, size_t argn, size_t retn) {
	callref((int)eid, argn, retn);
}

lua_event_listener::lua_event_listener(lua_plugin* p, const Rml::String& code, Rml::Element* element)
	: plugin(p) {
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		Rml::ElementDocument* doc = element->GetOwnerDocument();
		lua_pushlightuserdata(L, (void*)this);
		lua_pushlightuserdata(L, (void*)doc);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, code.c_str(), code.length());
		plugin->call(LuaEvent::OnEventAttach, 4);
	});
}

lua_event_listener::~lua_event_listener() {
	// element should be the same with Init
	lua_State* L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		plugin->call(LuaEvent::OnEventDetach, 1);
	});
}

void lua_event_listener::ProcessEvent(Rml::Event& event) {
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		lua_pushevent(L, event);
		plugin->call(LuaEvent::OnEvent, 2);
	});
}

void lua_event_listener::OnDetach(Rml::Element* element) {
	delete this;
}
