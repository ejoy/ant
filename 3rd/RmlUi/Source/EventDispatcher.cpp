/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "EventDispatcher.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Event.h"
#include "../Include/RmlUi/EventListener.h"
#include "../Include/RmlUi/EventSpecification.h"
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


bool DispatchEvent(Event& e, bool bubbles) {
	std::vector<CollectedListener> listeners;
	
	int depth = 0;
	EventId id = e.GetId();
	Element* walk_element = e.GetTargetElement();
	while (walk_element) {
		for (auto const& listener : walk_element->GetEventListeners()) {
			if (listener->id == id) {
				if (listener->use_capture) {
					listeners.emplace_back(walk_element, listener, depth, true);
				}
				else if (bubbles || (depth == 0)) {
					listeners.emplace_back(walk_element, listener, depth, false);
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
		if (!e.IsPropagating())
			break;
		Element* element = listener_desc.element.get();
		if (element) {
			EventListener* listener = listener_desc.listener.get();
			if (listener) {
				e.SetCurrentElement(element);
				e.SetPhase(listener_desc.GetPhase());
				listener->ProcessEvent(e);
			}
		}
		if (!e.IsImmediatePropagating())
			break;
	}
	return e.IsPropagating();
}

}
