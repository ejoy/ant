#pragma once

#include <core/Tween.h>
#include <core/ID.h>
#include <map>
#include <string>
#include <variant>

namespace Rml {

struct Transition {
	Tween tween;
	float duration = 0.0f;
	float delay = 0.0f;
};

struct Animation {
	Transition transition;
	bool alternate = false;
	bool paused = false;
	int num_iterations = 1;
	std::string name;
};

struct TransitionNone {};
struct TransitionAll: public Transition { };
struct TransitionList { std::map<PropertyId, Transition> transitions; };
using Transitions = std::variant<TransitionNone, TransitionAll, TransitionList>;

inline bool operator==(const Transition& a, const Transition& b) { return a.tween == b.tween && a.duration == b.duration && a.delay == b.delay; }
inline bool operator==(const Animation& a, const Animation& b) { return a.transition == b.transition && a.alternate == b.alternate && a.paused == b.paused && a.num_iterations == b.num_iterations && a.name == b.name; }
inline bool operator==(const TransitionNone& a, const TransitionNone& b) { return true; }
inline bool operator==(const TransitionAll& a, const TransitionAll& b) { return (const Transition&)a == (const Transition&)b; }
inline bool operator==(const TransitionList& a, const TransitionList& b) { return a.transitions == b.transitions; }

}
