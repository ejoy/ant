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

#include "DataControllerDefault.h"
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Event.h"
#include "DataController.h"
#include "DataExpression.h"
#include "DataModel.h"

namespace Rml {

struct DataControllerEventListener : public EventListener {
	DataControllerEventListener(const std::string& type, bool use_capture, const std::string& expression_str)
		: EventListener(type, use_capture)
		, expression(expression_str)
	{ }
	bool Parse(const DataExpressionInterface& expression_interface, bool is_assignment_expression) {
		return expression.Parse(expression_interface, is_assignment_expression);
	}
	void OnDetach(Element *) override {}
	void ProcessEvent(Event& event) override {
		Element* element = event.GetTargetElement();
		DataExpressionInterface expr_interface(element->GetDataModel(), element, &event);
		Variant unused_value_out;
		expression.Run(expr_interface, unused_value_out);
	}
	DataExpression expression;
};

DataControllerEvent::DataControllerEvent(Element* element)
	: DataController(element)
{}

DataControllerEvent::~DataControllerEvent()
{
	if (Element* element = GetElement()) {
		if (listener) {
			element->RemoveEventListener(listener.get());
		}
	}
}

bool DataControllerEvent::Initialize(DataModel& model, Element* element, const std::string& expression_str, const std::string& modifier)
{
	assert(element);
	listener = std::make_unique<DataControllerEventListener>(modifier, false, expression_str);
	DataExpressionInterface expr_interface(&model, element);
	if (!listener->Parse(expr_interface, true)) {
		listener.reset();
		return false;
	}
	element->AddEventListener(listener.get());
	return true;
}

}
