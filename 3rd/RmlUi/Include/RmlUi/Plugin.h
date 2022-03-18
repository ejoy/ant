#pragma once

#include <string>

namespace Rml {

class Element;
class EventListener;
class Document;

class Plugin {
public:
	virtual EventListener* OnCreateEventListener(Element* element, const std::string& type, const std::string& code, bool use_capture) = 0;
	virtual void OnLoadInlineScript(Document* document, const std::string& content, const std::string& source_path, int source_line) = 0;
	virtual void OnLoadExternalScript(Document* document, const std::string& source_path) = 0;
	virtual void OnCreateElement(Document* document, Element* element, const std::string& tag) = 0;
};

}
