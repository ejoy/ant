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

#include "../Include/RmlUi/Event.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Document.h"
#include "EventSpecification.h"

namespace Rml {

Event::Event(Element* _target_element, EventId id, const Dictionary& _parameters, bool interruptible)
	: parameters(_parameters)
	, target_element(_target_element)
	, id(id)
	, interruptible(interruptible)
{
	switch (id) {
	case EventId::Mousedown:
	case EventId::Mouseup:
	case EventId::Mousemove:
	case EventId::Mousescroll:
	case EventId::Mouseover:
	case EventId::Mouseout:
	case EventId::Click:
	case EventId::Dblclick:
	case EventId::Dragmove:
	case EventId::Drag:
	case EventId::Dragstart:
	case EventId::Dragover:
	case EventId::Dragdrop:
	case EventId::Dragout:
	case EventId::Dragend:
		InitMouseEvent();
		break;
	}
}

Event::~Event()
{ }

void Event::InitMouseEvent() {
	const Variant* x = GetIf(parameters, "x");
	const Variant* y = GetIf(parameters, "y");
	if (!x || !y) {
		return;
	}
	Point client(0,0);
	x->GetInto(client.x);
	y->GetInto(client.y);

	parameters["clientX"] = client.x;
	parameters["clientY"] = client.y;

	Point offset = client;
	if (target_element->Project(offset)) {
		parameters["offsetX"] = offset.x;
		parameters["offsetY"] = offset.y;
	}

	Document* document = target_element->GetOwnerDocument();
	if (document) {
		Point page = client;
		if (document->body->Project(page)) {
			parameters["pageX"] = page.x;
			parameters["pageY"] = page.y;
		}
	}
}

void Event::SetCurrentElement(Element* element) {
	current_element = element;
}

Element* Event::GetCurrentElement() const {
	return current_element;
}

Element* Event::GetTargetElement() const {
	return target_element;
}

void Event::SetPhase(EventPhase _phase)
{
	phase = _phase;
}

EventPhase Event::GetPhase() const {
	return phase;
}

bool Event::IsPropagating() const {
	return !interrupted;
}

void Event::StopPropagation() {
	if (interruptible) {
		interrupted = true;
	}
}

bool Event::IsImmediatePropagating() const {
	return !interrupted_immediate;
}

bool Event::IsInterruptible() const {
	return interruptible;
}

void Event::StopImmediatePropagation() {
	if (interruptible) {
		interrupted_immediate = true;
		interrupted = true;
	}
}

const Dictionary& Event::GetParameters() const {
	return parameters;
}

EventId Event::GetId() const {
	return id;
}

String Event::GetType() const {
	return EventSpecificationInterface::Get(id).type;
}

} // namespace Rml
