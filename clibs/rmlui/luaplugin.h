#ifndef ant_rml_lua_plugin_h
#define ant_rml_lua_plugin_h

#include "luabind.h"
#include "RmlUi/Plugin.h"

class lua_event_listener;
class lua_event_listener_instancer;

namespace Rml {
class Element;
class Document;
}

enum class LuaEvent : int {
	OnDocumentCreate = 1,
	OnDocumentDestroy,
	OnLoadInlineScript,
	OnLoadExternalScript,
	OnEvent,
	OnEventAttach,
	OnEventDetach,
	OnOpenFile,
};

class lua_plugin final : public Rml::Plugin {
public:
	~lua_plugin();
	void OnInitialise() override;
	void OnShutdown() override;
	void OnDocumentCreate(Rml::Document* document) override;
	void OnDocumentDestroy(Rml::Document* document) override;
	void OnLoadInlineScript(Rml::Document* document, const std::string& content, const std::string& source_path, int source_line) override;
	void OnLoadExternalScript(Rml::Document* document, const std::string& source_path) override;

	void register_event(lua_State* L);
	int  ref(lua_State* L);
	void unref(int ref);
	void callref(lua_State* L, int ref, size_t argn = 0, size_t retn = 0);
	void call(lua_State* L, LuaEvent eid, size_t argn = 0, size_t retn = 0);

	std::unique_ptr<luabind::reference> reference;
	lua_event_listener_instancer* event_listener_instancer = nullptr;
};

lua_plugin* get_lua_plugin();
void lua_pushvariant(lua_State *L, const Rml::Variant &v);
void lua_getvariant(lua_State *L, int index, Rml::Variant* variant);
void lua_pushvariant(lua_State *L, const Rml::EventVariant &v);
void lua_getvariant(lua_State *L, int index, Rml::EventVariant* variant);
void lua_pushevent(lua_State* L, const Rml::Event& event);


#endif
