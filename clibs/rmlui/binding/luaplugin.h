#ifndef ant_rml_lua_plugin_h
#define ant_rml_lua_plugin_h

#include "luabind.h"
#include "luaref.h"
#include "core/Plugin.h"
#include "core/Variant.h"

class lua_event_listener;

namespace Rml {
class Element;
class EventListener;
class Document;
}

enum class LuaEvent : int {
	OnLoadInlineScript = 2,
	OnLoadExternalScript,
	OnCreateElement,
	OnEvent,
	OnEventAttach,
	OnEventDetach,
	OnOpenFile,
};

class lua_plugin final : public Rml::Plugin {
public:
	~lua_plugin();
	Rml::EventListener* OnCreateEventListener(Rml::Element* element, const std::string& type, const std::string& code, bool use_capture) override;
	void OnLoadInlineScript(Rml::Document* document, const std::string& content, const std::string& source_path, int source_line) override;
	void OnLoadExternalScript(Rml::Document* document, const std::string& source_path) override;
	void OnCreateElement(Rml::Document* document, Rml::Element* element, const std::string& tag) override;

	void register_event(lua_State* L);
	int  ref(lua_State* L);
	void unref(int ref);
	void callref(lua_State* L, int ref, size_t argn = 0, size_t retn = 0);
	void call(lua_State* L, LuaEvent eid, size_t argn = 0, size_t retn = 0);
	void pushevent(lua_State* L, const Rml::Event& event);

	luaref reference = 0;
};

lua_plugin* get_lua_plugin();
void lua_pushvariant(lua_State *L, const Rml::Variant &v);
void lua_getvariant(lua_State *L, int index, Rml::Variant* variant);


#endif
