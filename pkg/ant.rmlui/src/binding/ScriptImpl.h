#pragma once

#include <core/Interface.h>
#include <bee/lua/luaref.h>

namespace Rml {
class Node;
class Element;
class Document;
class Event;

class ScriptImpl final : public Script {
public:
	ScriptImpl(lua_State* L);
	~ScriptImpl();
	void OnCreateElement(Document* document, Element* element, const std::string& tag) override;
	void OnCreateText(Document* document, Text* text) override;
	void OnDispatchEvent(Document* document, Element* element, const std::string& type, const luavalue::table& eventData) override;
	void OnDestroyNode(Document* document, Node* node) override;
	void OnLoadTexture(Document* document, Element* element, const std::string& path) override;
	void OnLoadTexture(Document* document, Element* element, const std::string& path, Size size) override;
	void OnParseText(const std::string& str,std::vector<group>& groups,std::vector<int>& groupMap,std::vector<image>& images,std::vector<int>& imageMap,std::string& ctext,group& default_group) override;
private:
	luaref reference = 0;
};

}
