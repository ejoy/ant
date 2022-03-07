#pragma once

#include "Platform.h"
#include "Types.h"
#include "ID.h"

namespace Rml {

class Element;

enum class EventPhase { None, Capture = 1, Target = 2, Bubble = 4 };

class Event {
public:
	Event(Element* target, const std::string& type, const EventDictionary& parameters, bool interruptible);
	virtual ~Event();

	EventPhase GetPhase() const;
	void SetPhase(EventPhase phase);

	void SetCurrentElement(Element* element);
	Element* GetCurrentElement() const;
	Element* GetTargetElement() const;

	const std::string& GetType() const;

	void StopPropagation();
	void StopImmediatePropagation();

	bool IsInterruptible() const;
	bool IsPropagating() const;
	bool IsImmediatePropagating() const;

	const EventDictionary& GetParameters() const;

protected:
	EventDictionary parameters;
	Element* target_element = nullptr;
	Element* current_element = nullptr;

private:
	std::string type;
	bool interruptible = false;
	bool interrupted = false;
	bool interrupted_immediate = false;
	EventPhase phase = EventPhase::None;
};


}
