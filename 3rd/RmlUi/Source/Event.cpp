#include "../Include/RmlUi/Event.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Document.h"

namespace Rml {

Event::Event(Element* _target_element, const std::string& type, const EventDictionary& _parameters, bool interruptible)
	: parameters(_parameters)
	, target_element(_target_element)
	, type(type)
	, interruptible(interruptible)
{ }

Event::~Event()
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

void Event::SetPhase(EventPhase _phase)
{
	phase = _phase;
}

EventPhase Event::GetPhase() const {
	return phase;
}

bool Event::IsPropagating() const {
	return !interrupted;
}

void Event::StopPropagation() {
	if (interruptible) {
		interrupted = true;
	}
}

bool Event::IsImmediatePropagating() const {
	return !interrupted_immediate;
}

bool Event::IsInterruptible() const {
	return interruptible;
}

void Event::StopImmediatePropagation() {
	if (interruptible) {
		interrupted_immediate = true;
		interrupted = true;
	}
}

const EventDictionary& Event::GetParameters() const {
	return parameters;
}

const std::string& Event::GetType() const {
	return type;
}

}
