#pragma once

#include <util/ObserverPtr.h>
#include <string>

namespace Rml {

class Event;
class Element;

class EventListener : public EnableObserverPtr<EventListener> {
public:
	EventListener(const std::string& type)
		: type(type)
	{}
	virtual ~EventListener() {}
	virtual void ProcessEvent(Event& event) = 0;

	std::string type;
};

}
