#include "pch.h"

#include <RmlUi/Core.h>
#include <RmlUi/Core/Plugin.h>
#include <RmlUi/Core/ElementDocument.h>
#include <RmlUi/Core/ElementInstancer.h>
#include <RmlUi/Core/Stream.h>

extern "C" {
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
}

#include "luaplugin.h"
#include "luabind.h"

static int LUA_PLUGIN = 0;

namespace {

class lua_plugin;

class lua_document final : public Rml::ElementDocument {
public:
	lua_document(lua_plugin *p, const Rml::String& tag) : Rml::ElementDocument(tag), plugin(p) {
		Init();
	}
private:
	~lua_document();
	void Init();
	void LoadScript(Rml::Stream* stream, const Rml::String& source_name) override;

	lua_plugin *plugin;
};

class lua_element final : public Rml::Element {
public:
	lua_element(Rml::Element* parent, const Rml::String& tag) : Rml::Element(tag) {
		SetOwnerDocument(parent ? parent->GetOwnerDocument() : nullptr);
	}
};

class lua_event_listener final : public Rml::EventListener {
public:
	lua_event_listener(lua_plugin *p, const Rml::String& code, Rml::Element* element) : plugin(p) {
		Init(code, element);
	}
private:
	void Init(const Rml::String& code, Rml::Element* element);
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

class lua_element_instancer final : public Rml::ElementInstancer {
public:
	lua_element_instancer() {}
private:
	Rml::ElementPtr InstanceElement(Rml::Element* parent, const Rml::String& tag, const Rml::XMLAttributes& attributes) override {
		// ignore attributes
		return Rml::ElementPtr(new lua_element(parent, tag));
	}
	void ReleaseElement(Rml::Element* element) override {
		delete element;
	}
};

class lua_document_instancer final : public Rml::ElementInstancer {
public:
	lua_document_instancer(lua_plugin *p) : plugin(p) {}
private:
	Rml::ElementPtr InstanceElement(Rml::Element* parent, const Rml::String& tag, const Rml::XMLAttributes& attributes) override {
		// ignore parent and attributes
		return Rml::ElementPtr(new lua_document(plugin, tag));
	}
	void ReleaseElement(Rml::Element* element) override {
		delete element;
	}

	lua_plugin *plugin;
};

class lua_plugin final : public Rml::Plugin {
public:
	~lua_plugin() {
		delete document_element_instancer;
		delete event_listener_instancer;
		document_element_instancer = nullptr;
		event_listener_instancer = nullptr;
	}

	int GetEventClasses() override {
		return EVT_BASIC;
	}
	void OnInitialise() override {
		document_element_instancer = new lua_document_instancer(this);
		element_instancer = new lua_element_instancer();
		event_listener_instancer = new lua_event_listener_instancer(this);
		Rml::Factory::RegisterElementInstancer("body", document_element_instancer);
		Rml::Factory::RegisterElementInstancer("*", element_instancer);
		Rml::Factory::RegisterEventListenerInstancer(event_listener_instancer);
	}
	void OnShutdown() override {
		delete this;
	}
	void OnContextCreate(Rml::Context* context) override {
		luabind::invoke(L, [&]() {
			lua_pushlightuserdata(L, (void*)context);
			lua_plugin_call(L, "OnContextCreate", 1);
		});	
	}
	void OnContextDestroy(Rml::Context* context) override {
		luabind::invoke(L, [&]() {
			lua_pushlightuserdata(L, (void*)context);
			lua_plugin_call(L, "OnContextDestroy", 1);
		});
	}

	static void check_function(lua_State *L, const char *funcname) {
		if (lua_getfield(L, -1, funcname) != LUA_TFUNCTION)
			luaL_error(L, "Missing %s", funcname);
		lua_pop(L, 1);
	}

	static void check_module(lua_State *L) {
		if (!lua_istable(L, -1))
			luaL_error(L, "Init need a module table");
		check_function(L, "OnContextCreate");
		check_function(L, "OnContextDestroy");
		check_function(L, "OnNewDocument");
		check_function(L, "OnDeleteDocument");
		check_function(L, "OnInlineScript");
		check_function(L, "OnExternalScript");
		check_function(L, "OnEvent");
		check_function(L, "OnEventAttach");
		check_function(L, "OnEventDetach");
		check_function(L, "OnUpdate");
		check_function(L, "OnOpenFile");
	}

	static void shutdown_error(lua_State *L, lua_plugin *p) {
		p->OnShutdown();
		lua_error(L);
	}

	void InitLuaVM(lua_State* L, const char* source, size_t sz) {
		luaL_openlibs(L);
		luaL_requiref(L, "rmlui", lua_plugin_apis, 1);
		lua_pop(L, 1);
		int err = luaL_loadbuffer(L, source, sz, source);
		if (err) {
			lua_error(L);
			return;
		}
		lua_call(L, 0, 1);
		check_module(L);
		lua_rawsetp(L, LUA_REGISTRYINDEX, &LUA_PLUGIN);
		this->L = L;
	}

	lua_State *L = nullptr;
	friend class lua_document;
	friend class lua_event_listener;
	lua_document_instancer* document_element_instancer = nullptr;
	lua_element_instancer* element_instancer = nullptr;
	lua_event_listener_instancer* event_listener_instancer = nullptr;
};

void lua_document::Init() {
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		lua_plugin_call(L, "OnNewDocument", 1);
	});
}

lua_document::~lua_document() {
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		lua_plugin_call(L, "OnDeleteDocument", 1);
	});
}

void
lua_document::LoadScript(Rml::Stream* stream, const Rml::String& source_name) {
	lua_State* L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		if (!source_name.empty()) {
			lua_pushlstring(L, source_name.c_str(), source_name.length());
			lua_plugin_call(L, "OnExternalScript", 2);
		}
		else {
			Rml::String buffer;
			stream->Read(buffer, stream->Length());
			lua_pushlstring(L, buffer.c_str(), buffer.length());
			lua_plugin_call(L, "OnInlineScript", 2);
		}
	});
}

void lua_event_listener::Init(const Rml::String& code, Rml::Element* element) {
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		Rml::ElementDocument* doc = element->GetOwnerDocument();
		lua_pushlightuserdata(L, (void*)this);
		lua_pushlightuserdata(L, (void*)doc);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, code.c_str(), code.length());
		lua_plugin_call(L, "OnEventAttach", 4);
	});
}

void lua_event_listener::OnDetach(Rml::Element* element) {
	// element should be the same with Init
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		lua_plugin_call(L, "OnEventDetach", 1);
	});
}

void lua_event_listener::ProcessEvent(Rml::Event& event) {
	lua_State *L = plugin->L;
	luabind::invoke(L, [&]() {
		lua_pushlightuserdata(L, (void*)this);
		auto& p = event.GetParameters();
		if (p.empty()) {
			lua_pushnil(L);
		}
		else {
			lua_createtable(L, 0, (int)p.size());
			for (auto& v : p) {
				lua_pushlstring(L, v.first.c_str(), v.first.length());
				lua_pushvariant(L, v.second);
				lua_rawset(L, -3);
			}
		}
		lua_pushinteger(L, (lua_Integer)event.GetId());
		lua_plugin_call(L, "OnEvent", 3);
	});
}

}

Rml::Plugin*
lua_plugin_create() {
	return new lua_plugin();
}

void
lua_plugin_init(Rml::Plugin* plugin, lua_State* L, const char* source, size_t sz) {
	((lua_plugin*)plugin)->InitLuaVM(L, source, sz);
}

void
lua_plugin_call(lua_State* L, const char* name, size_t argn, size_t retn) {
	lua_rawgetp(L, LUA_REGISTRYINDEX, &LUA_PLUGIN);
	lua_getfield(L, -1, name);
	lua_replace(L, -2);
	lua_insert(L, -1 - (int)argn);
	lua_call(L, (int)argn, (int)retn);
}

void
lua_plugin_destroy(Rml::Plugin* plugin) {
	delete plugin;
}
