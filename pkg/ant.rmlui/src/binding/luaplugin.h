#pragma once

#include <binding/luabind.h>
#include <core/Interface.h>
#include "luaref.h"

namespace Rml {

class Node;
class Element;
class Document;
class Event;

enum class LuaEvent : uint8_t {
	OnCreateElement = 2,
	OnCreateText,
	OnDispatchEvent,
	OnDestroyNode,
	OnLoadTexture,
	OnParseText,
};

class LuaPlugin final : public Plugin {
public:
	LuaPlugin(lua_State* L);
	~LuaPlugin();
	void OnCreateElement(Document* document, Element* element, const std::string& tag) override;
	void OnCreateText(Document* document, Text* text) override;
	void OnDispatchEvent(Document* document, Element* element, const std::string& type, const luavalue::table& eventData) override;
	void OnDestroyNode(Document* document, Node* node) override;
	void OnLoadTexture(Document* document, Element* element, const std::string& path) override;
	void OnLoadTexture(Document* document, Element* element, const std::string& path, Size size) override;
	void OnParseText(const std::string& str,std::vector<group>& groups,std::vector<int>& groupMap,std::vector<image>& images,std::vector<int>& imageMap,std::string& ctext,group& default_group) override;
private:
	void register_event(lua_State* L);
	luaref_box ref(lua_State* L);
	void callref(lua_State* L, int ref, size_t argn = 0, size_t retn = 0);
	void call(lua_State* L, LuaEvent eid, size_t argn = 0, size_t retn = 0);
	void pushevent(lua_State* L, const Event& event);
	luaref reference = 0;
};

}
