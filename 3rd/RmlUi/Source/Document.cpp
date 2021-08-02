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

#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "../Include/RmlUi/FileInterface.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "ElementStyle.h"
#include "EventDispatcher.h"
#include "StreamFile.h"
#include "StyleSheetFactory.h"
#include "DataModel.h"
#include "PluginRegistry.h"
#include "HtmlParser.h"
#include <set>
#include <fstream>

static constexpr float DOUBLE_CLICK_TIME = 0.5f;     // [s]
static constexpr float DOUBLE_CLICK_MAX_DIST = 3.f;  // [dp]

namespace Rml {

Document::Document(const Size& _dimensions)
	: body(new ElementDocument(this))
	, dimensions(_dimensions)
{
	style_sheet = nullptr;
	context = nullptr;
}

Document::~Document() {
	body.reset();
}


using namespace std::literals;

static bool isDataViewElement(Element* e) {
	for (const std::string& name : Factory::GetStructuralDataViewAttributeNames()) {
		if (e->GetTagName() == name) {
			return true;
		}
	}
	return false;
}

class DocumentHtmlHandler: public HtmlHandler {
	Document&             m_doc;
	ElementAttributes     m_attributes;
	std::shared_ptr<StyleSheet> m_style_sheet;
	std::stack<Element*>  m_stack;
	Element*              m_parent = nullptr;
	Element*              m_current = nullptr;
	size_t                m_line = 0;

public:
	DocumentHtmlHandler(Document& doc)
		: m_doc(doc)
	{}
	void OnDocumentBegin() override {}
	void OnDocumentEnd() override {
		if (m_style_sheet) {
			m_doc.SetStyleSheet(std::move(m_style_sheet));
		}
	}
	void OnElementBegin(const char* szName) override {
		m_attributes.clear();

		if (!m_current && szName == "body"sv) {
			m_current = m_doc.body.get();
			return;
		}
		if (!m_current) {
			return;
		}
		m_stack.push(m_current);
		m_parent = m_current;
		m_current = new Element(&m_doc, szName);
	}
	void OnElementClose() override {
		if (m_parent && m_current) {
			m_parent->AppendChild(ElementPtr(m_current));
		}
	}
	void OnElementEnd(const  char* szName) override {
		if (!m_current) {
			return;
		}
		if (m_stack.empty()) {
			m_current = nullptr;
		}
		else {
			m_current = m_stack.top();
			m_stack.pop();
		}
	}
	void OnCloseSingleElement(const  char* szName) override {
		if (szName == "script"sv) {
			auto it = m_attributes.find("path");
			if (it != m_attributes.end()) {
				m_doc.LoadExternalScript(it->second);
			}
		}
		else if (szName == "style"sv) {
			auto it = m_attributes.find("path");
			if (it != m_attributes.end()) {
				LoadExternalStyle(it->second);
			}
		}
		else {
			OnElementEnd(szName);
		}
	}
	void OnAttribute(const char* szName, const char* szValue) override {
		if (m_current) {
			m_current->SetAttribute(szName, szValue);
		}
		else {
			m_attributes.emplace(szName, szValue);
		}
	}
	void OnTextBegin() override {}
	void OnTextEnd(const char* szValue) override {
		if (m_current) {
			if (isDataViewElement(m_current) && ElementUtilities::ApplyStructuralDataViews(m_current, szValue)) {
				return;
			}
			Factory::InstanceElementText(m_current, szValue);
		}
	}
	void OnComment(const char* szText) override {}
	void OnScriptBegin(unsigned int line) override {
		m_line = line;
	}
	void OnScriptEnd(const char* szValue) override {
		auto it = m_attributes.find("path");
		if (it == m_attributes.end()) {
			m_doc.LoadInlineScript(szValue, m_doc.GetSourceURL(), m_line);
		}
		else {
			m_doc.LoadExternalScript(it->second);
		}
	}
	void OnStyleBegin(unsigned int line) override {
		m_line = line;
	}
	void LoadInlineStyle(const std::string& content, const std::string& source_path, int line) {
		std::unique_ptr<StyleSheet> inline_sheet = std::make_unique<StyleSheet>();
		auto stream = std::make_unique<StreamMemory>((const byte*)content.data(), content.size());
		stream->SetSourceURL(source_path);
		if (inline_sheet->LoadStyleSheet(stream.get(), line)) {
			if (m_style_sheet) {
				std::shared_ptr<StyleSheet> combined_sheet = m_style_sheet->CombineStyleSheet(*inline_sheet);
				m_style_sheet = combined_sheet;
			}
			else
				m_style_sheet = std::move(inline_sheet);
		}
		stream.reset();
	}
	void LoadExternalStyle(const std::string& source_path) {
		std::shared_ptr<StyleSheet> sub_sheet = StyleSheetFactory::GetStyleSheet(source_path);
		if (sub_sheet) {
			if (m_style_sheet) {
				std::shared_ptr<StyleSheet> combined_sheet = m_style_sheet->CombineStyleSheet(*sub_sheet);
				m_style_sheet = std::move(combined_sheet);
			}
			else
				m_style_sheet = sub_sheet;
		}
		else
			Log::Message(Log::Level::Error, "Failed to load style sheet %s.", source_path.c_str());
	}
	void OnStyleEnd(const char* szValue) override {
		auto it = m_attributes.find("path");
		if (it == m_attributes.end()) {
			LoadInlineStyle(szValue, m_doc.GetSourceURL(), m_line);
		}
		else {
			LoadExternalStyle(it->second);
		}
	}
};

bool Document::Load(const std::string& path) {
	try {
		std::ifstream input(GetFileInterface()->GetPath(path));
		if (!input) {
			return false;
		}
		std::string data((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
		input.close();

		source_url = path;
		HtmlParser parser;
		DocumentHtmlHandler handler(*this);
		parser.Parse(data, &handler);
		body->UpdateProperties();
	}
	catch (HtmlParserException& e) {
		Log::Message(Log::Level::Error, "%s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		return false;
	}
	return true;
}

// Returns the document's context.
Context* Document::GetContext()
{
	return context;
}

const std::string& Document::GetSourceURL() const
{
	return source_url;
}

// Sets the style sheet this document, and all of its children, uses.
void Document::SetStyleSheet(std::shared_ptr<StyleSheet> _style_sheet)
{
	if (style_sheet == _style_sheet)
		return;

	style_sheet = std::move(_style_sheet);
	
	if (style_sheet)
	{
		style_sheet->BuildNodeIndex();
	}

	body->GetStyle()->DirtyDefinition();
}

// Returns the document's style sheet.
const std::shared_ptr<StyleSheet>& Document::GetStyleSheet() const
{
	return style_sheet;
}

void Document::Show() {
	GetContext()->SetFocus(this);
	body->DispatchEvent(EventId::Show, Dictionary());
}

void Document::Hide() {
	body->DispatchEvent(EventId::Hide, Dictionary());
	if (GetContext()->GetFocus() == this) {
		GetContext()->SetFocus(nullptr);
	}
}

// Close this document
void Document::Close()
{
	if (context != nullptr)
		context->UnloadDocument(this);
}

ElementPtr Document::CreateElement(const std::string& name)
{
	ElementPtr element(new Element(this, name));
	return element;
}

// Create a text element.
TextPtr Document::CreateTextNode(const std::string& str)
{
	TextPtr text(new ElementText(this, str));
	if (!text)
	{
		Log::Message(Log::Level::Error, "Failed to create text element, instancer didn't return a derivative of ElementText.");
		return nullptr;
	}
	return text;
}

// Default load inline script implementation
void Document::LoadInlineScript(const std::string& content, const std::string& source_path, int source_line)
{
	PluginRegistry::NotifyLoadInlineScript(this, content, source_path, source_line);
}

// Default load external script implementation
void Document::LoadExternalScript(const std::string& source_path)
{
	PluginRegistry::NotifyLoadExternalScript(this, source_path);
}

void Document::UpdateDataModel(bool clear_dirty_variables) {
	for (auto& data_model : data_models) {
		data_model.second->Update(clear_dirty_variables);
	}
}

void Document::DirtyDpProperties()
{
	body->GetStyle()->DirtyPropertiesWithUnitRecursive(Property::DP);
}

using ElementSet = std::set<Element*>;

using ElementObserverList = std::vector< ObserverPtr<Element> >;

class ElementObserverListBackInserter {
public:
	using iterator_category = std::output_iterator_tag;
	using value_type = void;
	using difference_type = void;
	using pointer = void;
	using reference = void;
	using container_type = ElementObserverList;

	ElementObserverListBackInserter(ElementObserverList& elements) : elements(&elements) {}
	ElementObserverListBackInserter& operator=(Element* element) {
		elements->push_back(element->GetObserverPtr());
		return *this;
	}
	ElementObserverListBackInserter& operator*() { return *this; }
	ElementObserverListBackInserter& operator++() { return *this; }
	ElementObserverListBackInserter& operator++(int) { return *this; }

private:
	ElementObserverList* elements;
};

static void SendEvents(const ElementSet& old_items, const ElementSet& new_items, EventId id, const Dictionary& parameters) {
	// We put our elements in observer pointers in case some of them are deleted during dispatch.
	ElementObserverList elements;
	std::set_difference(old_items.begin(), old_items.end(), new_items.begin(), new_items.end(), ElementObserverListBackInserter(elements));
	for (auto& element : elements)
	{
		if (element)
			element->DispatchEvent(id, parameters);
	}
}

static void GenerateKeyEventParameters(Dictionary& parameters, Input::KeyIdentifier key) {
	parameters["key"] = (int)key;
}

static void GenerateKeyModifierEventParameters(Dictionary& parameters, int key_modifier_state) {
	static const std::string property_names[] = {
		"ctrlKey",
		"shiftKey",
		"altKey",
		"metaKey",
	};
	for (int i = 0; i < sizeof(property_names) /sizeof(property_names[0]); ++i) {
		parameters[property_names[i]] = (int)((key_modifier_state & (1 << i)) > 0);
	}
}

static void GenerateMouseEventParameters(Dictionary& parameters, const Point& mouse_position, MouseButton button) {
	parameters.reserve(3);
	parameters["x"] = mouse_position.x;
	parameters["y"] = mouse_position.y;
	if (button != MouseButton::None)
		parameters["button"] = (int)button;
}

bool Document::ProcessKeyDown(Input::KeyIdentifier key, int key_modifier_state) {
	Dictionary parameters;
	GenerateKeyEventParameters(parameters, key);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);
	return body->DispatchEvent(EventId::Keydown, parameters);
}

bool Document::ProcessKeyUp(Input::KeyIdentifier key, int key_modifier_state) {
	Dictionary parameters;
	GenerateKeyEventParameters(parameters, key);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);
	return body->DispatchEvent(EventId::Keyup, parameters);
}

void Document::ProcessMouseMove(MouseButton button, int x, int y, int key_modifier_state) {
	// Check whether the mouse moved since the last event came through.
	Point old_mouse_position = mouse_position;
	bool mouse_moved = (x != mouse_position.x) || (y != mouse_position.y);
	if (mouse_moved) {
		mouse_position.x = x;
		mouse_position.y = y;
	}

	// Generate the parameters for the mouse events (there could be a few!).
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position, button);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	Dictionary drag_parameters;
	GenerateMouseEventParameters(drag_parameters, mouse_position, MouseButton::None);
	GenerateKeyModifierEventParameters(drag_parameters, key_modifier_state);

	// Update the current hover chain. This will send all necessary 'onmouseout', 'onmouseover', 'ondragout' and
	// 'ondragover' messages.
	UpdateHoverChain(parameters, drag_parameters, old_mouse_position);

	// Dispatch any 'onmousemove' events.
	if (mouse_moved) {
		if (hover) {
			hover->DispatchEvent(EventId::Mousemove, parameters);
		}
	}
}

void Document::ProcessMouseButtonDown(MouseButton button, int key_modifier_state) {
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position, button);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	if (button == MouseButton::Left)
	{
		active = hover;

		bool propagate = true;

		// Call 'onmousedown' on every item in the hover chain, and copy the hover chain to the active chain.
		if (hover)
			propagate = hover->DispatchEvent(EventId::Mousedown, parameters);

		if (propagate)
		{
			// Check for a double-click on an element; if one has occured, we send the 'dblclick' event to the hover
			// element. If not, we'll start a timer to catch the next one.
			Point distance = mouse_position - last_click_mouse_position;
			float mouse_distance_squared = distance.x * distance.x + distance.y * distance.y;
			float max_mouse_distance = DOUBLE_CLICK_MAX_DIST * GetContext()->GetDensityIndependentPixelRatio();

			double click_time = GetContext()->GetElapsedTime();

			if (active == last_click_element &&
				float(click_time - last_click_time) < DOUBLE_CLICK_TIME &&
				mouse_distance_squared < max_mouse_distance * max_mouse_distance)
			{
				if (hover)
					propagate = hover->DispatchEvent(EventId::Dblclick, parameters);

				last_click_element = nullptr;
				last_click_time = 0;
			}
			else
			{
				last_click_element = active;
				last_click_time = click_time;
			}
		}

		last_click_mouse_position = mouse_position;

		active_chain.insert(active_chain.end(), hover_chain.begin(), hover_chain.end());
	}
	else
	{
		// Not the primary mouse button, so we're not doing any special processing.
		if (hover)
			hover->DispatchEvent(EventId::Mousedown, parameters);
	}
}

void Document::ProcessMouseButtonUp(MouseButton button, int key_modifier_state) {
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position, button);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	// Process primary click.
	if (button == MouseButton::Left)
	{
		// The elements in the new hover chain have the 'onmouseup' event called on them.
		if (hover)
			hover->DispatchEvent(EventId::Mouseup, parameters);

		// If the active element (the one that was being hovered over when the mouse button was pressed) is still being
		// hovered over, we click it.
		if (hover && active)
		{
			active->DispatchEvent(EventId::Click, parameters);
		}

		// Unset the 'active' pseudo-class on all the elements in the active chain; because they may not necessarily
		// have had 'onmouseup' called on them, we can't guarantee this has happened already.
		std::for_each(active_chain.begin(), active_chain.end(), [](Element* element) {
			element->SetPseudoClass("active", false);
		});
		active_chain.clear();
		active = nullptr;
	}
	else
	{
		// Not the left mouse button, so we're not doing any special processing.
		if (hover)
			hover->DispatchEvent(EventId::Mouseup, parameters);
	}
}

void Document::ProcessMouseWheel(float wheel_delta, int key_modifier_state) {
	if (hover) {
		Dictionary scroll_parameters;
		GenerateKeyModifierEventParameters(scroll_parameters, key_modifier_state);
		scroll_parameters["wheel_delta"] = wheel_delta;

		hover->DispatchEvent(EventId::Mousescroll, scroll_parameters);
	}
}

void Document::UpdateHoverChain(const Dictionary& parameters, const Dictionary& drag_parameters, const Point& old_mouse_position) {
	Point position = mouse_position;

	hover = body->GetElementAtPoint(position);

	// Build the new hover chain.
	ElementSet new_hover_chain;
	Element* element = hover;
	while (element != nullptr)
	{
		new_hover_chain.insert(element);
		element = element->GetParentNode();
	}

	// Send mouseout / mouseover events.
	SendEvents(hover_chain, new_hover_chain, EventId::Mouseout, parameters);
	SendEvents(new_hover_chain, hover_chain, EventId::Mouseover, parameters);

	// Swap the new chain in.
	hover_chain.swap(new_hover_chain);
}

void Document::OnElementDetach(Element* element) {
	auto it_hover = hover_chain.find(element);
	if (it_hover != hover_chain.end())
	{
		Dictionary parameters;
		GenerateMouseEventParameters(parameters, mouse_position, MouseButton::None);
		element->DispatchEvent(EventId::Mouseout, parameters);

		hover_chain.erase(it_hover);

		if (hover == element)
			hover = nullptr;
	}

	auto it_active = std::find(active_chain.begin(), active_chain.end(), element);
	if (it_active != active_chain.end())
	{
		active_chain.erase(it_active);

		if (active == element)
			active = nullptr;
	}
}

DataModelConstructor Document::CreateDataModel(const std::string& name) {
	auto result = data_models.emplace(name, std::make_unique<DataModel>());
	bool inserted = result.second;
	if (inserted)
		return DataModelConstructor(result.first->second.get());

	Log::Message(Log::Level::Error, "Data model name '%s' already exists.", name.c_str());
	return DataModelConstructor();
}

DataModelConstructor Document::GetDataModel(const std::string& name) {
	if (DataModel* model = GetDataModelPtr(name))
		return DataModelConstructor(model);
	Log::Message(Log::Level::Error, "Data model name '%s' could not be found.", name.c_str());
	return DataModelConstructor();
}

bool Document::RemoveDataModel(const std::string& name) {
	auto it = data_models.find(name);
	if (it == data_models.end())
		return false;

	DataModel* model = it->second.get();
	ElementList elements = model->GetAttachedModelRootElements();

	for (Element* element : elements)
		element->SetDataModel(nullptr);

	data_models.erase(it);

	return true;
}

DataModel* Document::GetDataModelPtr(const std::string& name) const {
	auto it = data_models.find(name);
	if (it != data_models.end())
		return it->second.get();
	return nullptr;
}

void Document::SetDimensions(const Size& _dimensions) {
	if (dimensions != _dimensions) {
		dirty_dimensions = true;
		dimensions = _dimensions;
		body->DispatchEvent(EventId::Resize, Dictionary());
	}
}

void Document::Update() {
	body->Update();
	if (dirty_dimensions || body->GetLayout().IsDirty()) {
		dirty_dimensions = false;
		body->GetLayout().CalculateLayout(dimensions);
	}
	body->UpdateLayout();
}

void Document::Render() {
	body->OnRender();
}

} // namespace Rml
