#pragma once

#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Event.h"

namespace Rml {

class Event;
class Element;
class EventListener;
struct CollectedListener;

class EventDispatcher {
public:
	EventDispatcher(Element* element);
	~EventDispatcher();
	void AddEventListener(EventListener* listener);
	void RemoveEventListener(EventListener* listener);
	void DetachAllEvents();
	static bool DispatchEvent(Event& e, bool bubbles);

private:
	Element* element;
	std::vector<EventListener*> listeners;
};

}
