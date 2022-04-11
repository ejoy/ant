#pragma once

#include <core/ObserverPtr.h>
#include <string>

namespace Rml {

class Event;
class Element;

class EventListener : public EnableObserverPtr<EventListener> {
public:
	EventListener(const std::string& type, bool use_capture_)
		: type(type)
		, use_capture(use_capture_)
	{}
	virtual ~EventListener() {}
	virtual void ProcessEvent(Event& event) = 0;
	virtual void OnDetach(Element* element) = 0;

	std::string type;
	bool use_capture;
};

}
