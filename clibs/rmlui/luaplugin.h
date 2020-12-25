#ifndef ant_rml_lua_plugin_h
#define ant_rml_lua_plugin_h

#include "luabind.h"

class lua_document;
class lua_event_listener;
class lua_document_instancer;
class lua_element_instancer;
class lua_event_listener_instancer;

enum class LuaEvent : int {
	OnNewDocument = 1,
	OnDeleteDocument,
	OnInlineScript,
	OnExternalScript,
	OnEvent,
	OnEventAttach,
	OnEventDetach,
	OnUpdate,
	OnShutdown,
	OnOpenFile,
};

class lua_plugin final : public Rml::Plugin {
public:
	~lua_plugin();
	int GetEventClasses() override;
	void OnInitialise() override;
	void OnShutdown() override;

	bool initialize(const std::string& bootstrap, std::string& errmsg);
	int  ref(lua_State* L);
	void unref(int ref);
	void callref(int ref, size_t argn = 0, size_t retn = 0);
	void call(LuaEvent eid, size_t argn = 0, size_t retn = 0);

	lua_State* L = nullptr;
	std::unique_ptr<luabind::reference> reference;
	lua_document_instancer* document_element_instancer = nullptr;
	lua_element_instancer* element_instancer = nullptr;
	lua_event_listener_instancer* event_listener_instancer = nullptr;
};

lua_plugin* get_lua_plugin();
int lua_plugin_apis(lua_State *L);
void lua_pushvariant(lua_State *L, const Rml::Variant &v);
void lua_getvariant(lua_State *L, int index, Rml::Variant* variant);
void lua_pushevent(lua_State* L, const Rml::Event& event);

#endif
