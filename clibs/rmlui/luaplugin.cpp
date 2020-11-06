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
	void Init(lua_State *mL, int index) {
		if (!lua_isstring(mL, index)) {
			lua_pushstring(mL, "Need source string");
			shutdown_error(mL, this);
		}
		InitLuaVM(mL, index);
	}
private:
	int GetEventClasses() override {
		return EVT_BASIC;
	}
	void OnInitialise() override {
		document_element_instancer = new lua_document_instancer(this);
		event_listener_instancer = new lua_event_listener_instancer(this);
		Rml::Factory::RegisterElementInstancer("body", document_element_instancer);
		Rml::Factory::RegisterEventListenerInstancer(event_listener_instancer);
	}
	void OnShutdown() override {
		delete document_element_instancer;
		delete event_listener_instancer;
		delete this;
	}
	void call_lua_function(const char *name, int argn) {
		lua_rawgetp(L, LUA_REGISTRYINDEX, (void *)this);
		lua_getfield(L, -1, name);
		lua_replace(L, -2);
		lua_insert(L, -1 - argn);
		if (lua_pcall(L, argn, 0, 0) != LUA_OK) {
			// todo: use Rml log
			lua_writestringerror("%s Error :", name);
			const char *error_message = lua_tostring(L, -1);
			if (error_message == NULL)
				error_message = "[ERROR]";
			lua_writestringerror("%s\n", error_message);
			lua_pop(L, 1);
		}
	}
	void OnContextCreate(Rml::Context* context) override {
		lua_pushlightuserdata(L, (void *)context);
		call_lua_function("OnContextCreate", 1);	
	}
	void OnContextDestroy(Rml::Context* context) override {
		lua_pushlightuserdata(L, (void *)context);
		call_lua_function("OnContextDestroy", 1);	
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
		check_function(L, "OnLoadScript");
		check_function(L, "OnEvent");
		check_function(L, "OnEventAttach");
		check_function(L, "OnEventDetach");
	}

	static void shutdown_error(lua_State *L, lua_plugin *p) {
		p->OnShutdown();
		lua_error(L);
	}

	static int init_libs(lua_State *L) {
		luaL_openlibs(L);
		luaL_requiref(L, "rmlui", lua_plugin_apis, 1);
		lua_pop(L, 1);
		const char * source = (const char *)lua_touserdata(L, 1);
		size_t sz = lua_tointeger(L, 2);
		void *key = lua_touserdata(L, 3);
		int err = luaL_loadbuffer(L, source, sz, "RmlInit") || lua_pcall(L, 0, 1, 0);
		if (err)
			return lua_error(L);
		check_module(L);
		lua_rawsetp(L, LUA_REGISTRYINDEX, key);
		return 0;
	}

	void InitLuaVM(lua_State *mL, int index) {
		lua_State *L = luaL_newstate(); // todo: use own alloc
		if (L == NULL) {
			lua_pushstring(mL, "Lua VM init failed");
			shutdown_error(mL, this);
		}
		size_t sz;
		const char *libsource = lua_tolstring(mL, index, &sz);
		lua_pushcfunction(L, init_libs);
		lua_pushlightuserdata(L, (void *)libsource);
		lua_pushinteger(L, sz);
		lua_pushlightuserdata(L, (void *)this);
		if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
			const char *error_message = lua_tostring(L, -1);
			if (error_message == NULL)
				error_message = "[ERROR]";
			lua_pushfstring(mL, "Lua init error : %s\n", error_message);
			lua_close(L);
			shutdown_error(mL, this);
		}
		this->L = L;
	}

	lua_State *L = nullptr;
	friend class lua_document;
	friend class lua_event_listener;
	lua_document_instancer* document_element_instancer = nullptr;
	lua_event_listener_instancer* event_listener_instancer = nullptr;
};

void lua_document::Init() {
	lua_State *L = plugin->L;
	lua_pushlightuserdata(L, (void *)this);
	plugin->call_lua_function("OnNewDocument", 1);
}

lua_document::~lua_document() {
	lua_State *L = plugin->L;
	lua_pushlightuserdata(L, (void *)this);
	plugin->call_lua_function("OnDeleteDocument", 1);
}

void
lua_document::LoadScript(Rml::Stream* stream, const Rml::String& source_name) {
	lua_State *L = plugin->L;

	Rml::String buffer;
	stream->Read(buffer,stream->Length());
	lua_pushlstring(L, buffer.c_str(), buffer.length());

	lua_pushlightuserdata(L, (void *)this);

	if(!source_name.empty()) {
		lua_pushlstring(L, source_name.c_str(), source_name.length());
	} else {
		lua_pushnil(L);
	}
	plugin->call_lua_function("OnLoadScript", 3);
}

void lua_event_listener::Init(const Rml::String& code, Rml::Element* element) {
	lua_State *L = plugin->L;
	Rml::ElementDocument* doc = element->GetOwnerDocument();
	lua_pushlightuserdata(L, (void *)this);
	lua_pushlightuserdata(L, (void *)doc);
	lua_pushlightuserdata(L, (void *)element);
	lua_pushlstring(L, code.c_str(), code.length());
	plugin->call_lua_function("OnEventAttach", 4);
}

void lua_event_listener::OnDetach(Rml::Element* element) {
	// element should be the same with Init
	lua_State *L = plugin->L;
	lua_pushlightuserdata(L, (void *)this);
	plugin->call_lua_function("OnEventDetach", 1);
}

static void
lua_pushvariant(lua_State *L, const Rml::Variant &v) {
	switch (v.GetType()) {
	case Rml::Variant::Type::BOOL:
		lua_pushboolean(L, v.GetReference<bool>());
		break;
	case Rml::Variant::Type::BYTE:
		lua_pushinteger(L, v.GetReference<unsigned char>());
		break;
	case Rml::Variant::Type::CHAR: {
		char s[1] = {v.GetReference<char>() };
		lua_pushlstring(L, s, 1);
		break; }
	case Rml::Variant::Type::FLOAT:
		lua_pushnumber(L, v.GetReference<float>());
		break;
	case Rml::Variant::Type::DOUBLE:
		lua_pushnumber(L, v.GetReference<double>());
		break;
	case Rml::Variant::Type::INT:
		lua_pushinteger(L, v.GetReference<int>());
		break;
	case Rml::Variant::Type::INT64:
		lua_pushinteger(L, v.GetReference<int64_t>());
		break;
	case Rml::Variant::Type::STRING: {
		const Rml::String &s = v.GetReference<Rml::String>();
		lua_pushlstring(L, s.c_str(), s.length());
		break; }
	case Rml::Variant::Type::NONE:
	case Rml::Variant::Type::VECTOR2:
	case Rml::Variant::Type::VECTOR3:
	case Rml::Variant::Type::VECTOR4:
	case Rml::Variant::Type::COLOURF:
	case Rml::Variant::Type::COLOURB:
	case Rml::Variant::Type::SCRIPTINTERFACE:
	case Rml::Variant::Type::TRANSFORMPTR:
	case Rml::Variant::Type::TRANSITIONLIST:
	case Rml::Variant::Type::ANIMATIONLIST:
	case Rml::Variant::Type::DECORATORSPTR:
	case Rml::Variant::Type::FONTEFFECTSPTR:
	case Rml::Variant::Type::VOIDPTR:
	default:
		// todo
		lua_pushnil(L);
		break;
	}
}

void lua_event_listener::ProcessEvent(Rml::Event& event) {
	lua_State *L = plugin->L;
	lua_pushlightuserdata(L, (void *)this);
	auto &p = event.GetParameters();
	if (p.empty()) {
		lua_pushnil(L);
	} else {
		lua_createtable(L, 0, p.size());
		for (auto &v : p) {
			lua_pushlstring(L, v.first.c_str(), v.first.length());
			lua_pushvariant(L, v.second);
			lua_rawset(L, -3);
		}
	}
	lua_pushinteger(L, (lua_Integer)event.GetId());
	plugin->call_lua_function("OnEvent", 3);
}

}

void
lua_plugin_register(lua_State *L, int index) {
	lua_plugin * p = new lua_plugin();
	p->Init(L, index);
	Rml::RegisterPlugin(p);
}
