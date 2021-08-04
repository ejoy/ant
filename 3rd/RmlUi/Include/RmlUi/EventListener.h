#pragma once

#include "Header.h"
#include "Event.h"
#include "ObserverPtr.h"
#include "EventSpecification.h"

namespace Rml {

class Event;
class Element;

class EventListener : public EnableObserverPtr<EventListener> {
public:
	EventListener(const std::string& type, bool use_capture_)
		: id(GetIdOrInsert(type))
		, use_capture(use_capture_)
	{}
	virtual ~EventListener() {}
	virtual void ProcessEvent(Event& event) = 0;
	virtual void OnDetach(Element* element) = 0;

	EventId id;
	bool use_capture;

private:
	EventId GetIdOrInsert(const std::string& event_type) {
		EventId id = EventSpecification::GetId(event_type);
		if (id != EventId::Invalid) {
			return id;
		}
		return EventSpecification::NewId(event_type, true, true);
	}
};

}
