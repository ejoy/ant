#pragma once

#include <string>
#include <cstdint>

namespace Rml {

class Element;

class Event final {
public:
	Event(Element* target, const std::string& type, int parameters);
	void SetCurrentElement(Element* element);
	Element* GetCurrentElement() const;
	Element* GetTargetElement() const;
	const std::string& GetType() const;
	int GetParameters() const;

private:
	std::string type;
	Element* target_element;
	Element* current_element = nullptr;
	int parameters;
};

}
