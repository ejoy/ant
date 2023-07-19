#include <core/EventDispatcher.h>
#include <core/Element.h>
#include <core/Event.h>
#include <core/EventListener.h>
#include <algorithm>

namespace Rml {

struct CollectedListener {
	CollectedListener(Element* _element, EventListener* _listener, int sort)
		: element(_element->GetObserverPtr())
		, listener(_listener->GetObserverPtr())
		, sort(sort)
	{}

	ObserverPtr<Element> element;
	ObserverPtr<EventListener> listener;
	int sort = 0;

	bool operator<(const CollectedListener& other) const {
		return sort < other.sort;
	}
};


bool DispatchEvent(Event& event) {
	std::vector<CollectedListener> listeners;
	
	int depth = 0;
	auto const& type = event.GetType();
	Element* walk_element = event.GetTargetElement();
	while (walk_element) {
		for (auto const& listener : walk_element->GetEventListeners()) {
			if (listener->type == type) {
				listeners.emplace_back(walk_element, listener.get(), depth);
			}
		}
		walk_element = walk_element->GetParentNode();
		depth += 1;
	}

	if (listeners.empty())
		return true;

	std::stable_sort(listeners.begin(), listeners.end());

	for (const auto& listener_desc : listeners) {
		Element* element = listener_desc.element.get();
		if (element) {
			EventListener* listener = listener_desc.listener.get();
			if (listener) {
				event.SetCurrentElement(element);
				listener->ProcessEvent(event);
			}
		}
	}
	return true;
}

}
