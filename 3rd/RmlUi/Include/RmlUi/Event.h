#pragma once

#include <string>

namespace Rml {

class Element;

enum class EventPhase { None, Capture = 1, Target = 2, Bubble = 4 };

class Event final {
public:
	Event(Element* target, const std::string& type, int parameters, bool interruptible);
	EventPhase GetPhase() const;
	void SetPhase(EventPhase phase);
	void SetCurrentElement(Element* element);
	Element* GetCurrentElement() const;
	Element* GetTargetElement() const;
	const std::string& GetType() const;
	int GetParameters() const;
	void StopPropagation();
	void StopImmediatePropagation();
	bool IsInterruptible() const;
	bool IsPropagating() const;
	bool IsImmediatePropagating() const;

private:
	std::string type;
	Element* target_element;
	Element* current_element = nullptr;
	int parameters;
	bool interruptible;
	bool interrupted = false;
	bool interrupted_immediate = false;
	EventPhase phase = EventPhase::None;
};

}
