#pragma once

#include "Header.h"
#include "Event.h"
#include "ObserverPtr.h"

namespace Rml {

class Event;
class Element;

class EventListener : public EnableObserverPtr<EventListener> {
public:
	EventListener(EventId id_, bool use_capture_)
		: id(id_)
		, use_capture(use_capture_)
	{}
	virtual ~EventListener() {}
	virtual void ProcessEvent(Event& event) = 0;
	virtual void OnDetach(Element* element) = 0;

	EventId id;
	bool use_capture;
};

}
