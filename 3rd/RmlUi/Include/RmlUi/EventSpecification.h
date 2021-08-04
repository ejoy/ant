#pragma once

#include "Header.h"
#include "Event.h"

namespace Rml {

struct EventSpecification {
	EventId id;
	std::string type;
	bool interruptible;
	bool bubbles;

	static const EventSpecification& Get(EventId id);
	static EventId GetId(const std::string& event_type);
	static EventId NewId(const std::string& event_type, bool interruptible, bool bubbles);
};

}
