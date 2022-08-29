#include <core/EventDispatcher.h>
#include <core/Element.h>
#include <core/Event.h>
#include <core/EventListener.h>
#include <algorithm>

namespace Rml {

struct CollectedListener {
	CollectedListener(Element* _element, EventListener* _listener, int depth, bool in_capture_phase)
		: element(_element->GetObserverPtr())
		, listener(_listener->GetObserverPtr())
		, sort(depth * (in_capture_phase ? -1 : 1))
	{}

	ObserverPtr<Element> element;
	ObserverPtr<EventListener> listener;
	int sort = 0;

	EventPhase GetPhase() const { return sort < 0 ? EventPhase::Capture : (sort == 0 ? EventPhase::Target : EventPhase::Bubble); }
	bool operator<(const CollectedListener& other) const {
		return sort < other.sort;
	}
};


bool DispatchEvent(Event& event, bool bubbles) {
	std::vector<CollectedListener> listeners;
	
	int depth = 0;
	auto const& type = event.GetType();
	Element* walk_element = event.GetTargetElement();
	while (walk_element) {
		for (auto const& listener : walk_element->GetEventListeners()) {
			if (listener->type == type) {
				if (listener->use_capture) {
					listeners.emplace_back(walk_element, listener.get(), depth, true);
				}
				else if (bubbles || (depth == 0)) {
					listeners.emplace_back(walk_element, listener.get(), depth, false);
				}
			}
		}
		walk_element = walk_element->GetParentNode();
		depth += 1;
	}

	if (listeners.empty())
		return true;

	std::stable_sort(listeners.begin(), listeners.end());

	for (const auto& listener_desc : listeners) {
		if (!event.IsPropagating())
			break;
		Element* element = listener_desc.element.get();
		if (element) {
			EventListener* listener = listener_desc.listener.get();
			if (listener) {
				event.SetCurrentElement(element);
				event.SetPhase(listener_desc.GetPhase());
				listener->ProcessEvent(event);
			}
		}
		if (!event.IsImmediatePropagating())
			break;
	}
	return event.IsPropagating();
}

}
