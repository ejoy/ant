#include <core/Event.h>

namespace Rml {

Event::Event(Element* target_element, const std::string& type, int parameters)
	: type(type)
	, target_element(target_element)
	, parameters(parameters)
{ }

void Event::SetCurrentElement(Element* element) {
	current_element = element;
}

Element* Event::GetCurrentElement() const {
	return current_element;
}

Element* Event::GetTargetElement() const {
	return target_element;
}

int Event::GetParameters() const {
	return parameters;
}

const std::string& Event::GetType() const {
	return type;
}

}
