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
#include "../Include/RmlUi/SystemInterface.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "../Include/RmlUi/FileInterface.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "DocumentHeader.h"
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
	for (const String& name : Factory::GetStructuralDataViewAttributeNames()) {
		if (e->GetTagName() == name) {
			return true;
		}
	}
	return false;
}

class DocumentHtmlHandler: public HtmlHandler {
	Document&             m_doc;
	ElementAttributes     m_attributes;
	SharedPtr<StyleSheet> m_style_sheet;
	std::stack<Element*>  m_stack;
	Element*              m_current;
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
		Element* parent = m_current;
		m_stack.push(parent);
		m_current = new Element(&m_doc, szName);
		parent->AppendChild(ElementPtr(m_current));
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
				m_doc.LoadExternalScript(it->second.Get<std::string>());
			}
		}
		else if (szName == "style"sv) {
			auto it = m_attributes.find("path");
			if (it != m_attributes.end()) {
				LoadExternalStyle(it->second.Get<std::string>());
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
			m_doc.LoadExternalScript(it->second.Get<std::string>());
		}
	}
	void OnStyleBegin(unsigned int line) override {
		m_line = line;
	}
	void LoadInlineStyle(const std::string& content, const std::string& source_path, int line) {
		UniquePtr<StyleSheet> inline_sheet = MakeUnique<StyleSheet>();
		auto stream = MakeUnique<StreamMemory>((const byte*)content.data(), content.size());
		stream->SetSourceURL(source_path);
		if (inline_sheet->LoadStyleSheet(stream.get(), line)) {
			if (m_style_sheet) {
				SharedPtr<StyleSheet> combined_sheet = m_style_sheet->CombineStyleSheet(*inline_sheet);
				m_style_sheet = combined_sheet;
			}
			else
				m_style_sheet = std::move(inline_sheet);
		}
		stream.reset();
	}
	void LoadExternalStyle(const std::string& source_path) {
		SharedPtr<StyleSheet> sub_sheet = StyleSheetFactory::GetStyleSheet(source_path);
		if (sub_sheet) {
			if (m_style_sheet) {
				SharedPtr<StyleSheet> combined_sheet = m_style_sheet->CombineStyleSheet(*sub_sheet);
				m_style_sheet = std::move(combined_sheet);
			}
			else
				m_style_sheet = sub_sheet;
		}
		else
			Log::Message(Log::LT_ERROR, "Failed to load style sheet %s.", source_path.c_str());
	}
	void OnStyleEnd(const char* szValue) override {
		auto it = m_attributes.find("path");
		if (it == m_attributes.end()) {
			LoadInlineStyle(szValue, m_doc.GetSourceURL(), m_line);
		}
		else {
			LoadExternalStyle(it->second.Get<std::string>());
		}
	}
};

bool Document::Load(const String& path) {
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
		Log::Message(Log::LT_ERROR, "%s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		return false;
	}
	return true;
}

void Document::ProcessHeader(const DocumentHeader* header)
{
	// Store the source address that we came from
	source_url = header->source;

	// If a style-sheet (or sheets) has been specified for this element, then we load them and set the combined sheet
	// on the element; all of its children will inherit it by default.
	SharedPtr<StyleSheet> new_style_sheet;

	// Combine any inline sheets.
	for (const DocumentHeader::Resource& rcss : header->rcss)
	{
		if (rcss.is_inline)
		{
			UniquePtr<StyleSheet> inline_sheet = MakeUnique<StyleSheet>();
			auto stream = MakeUnique<StreamMemory>((const byte*)rcss.content.c_str(), rcss.content.size());
			stream->SetSourceURL(rcss.path);

			if (inline_sheet->LoadStyleSheet(stream.get(), rcss.line))
			{
				if (new_style_sheet)
				{
					SharedPtr<StyleSheet> combined_sheet = new_style_sheet->CombineStyleSheet(*inline_sheet);
					new_style_sheet = combined_sheet;
				}
				else
					new_style_sheet = std::move(inline_sheet);
			}

			stream.reset();
		}
		else
		{
			SharedPtr<StyleSheet> sub_sheet = StyleSheetFactory::GetStyleSheet(rcss.path);
			if (sub_sheet)
			{
				if (new_style_sheet)
				{
					SharedPtr<StyleSheet> combined_sheet = new_style_sheet->CombineStyleSheet(*sub_sheet);
					new_style_sheet = std::move(combined_sheet);
				}
				else
					new_style_sheet = sub_sheet;
			}
			else
				Log::Message(Log::LT_ERROR, "Failed to load style sheet %s.", rcss.path.c_str());
		}
	}

	// If a style sheet is available, set it on the document and release it.
	if (new_style_sheet)
	{
		SetStyleSheet(std::move(new_style_sheet));
	}

	// Load scripts.
	for (const DocumentHeader::Resource& script : header->scripts)
	{
		if (script.is_inline)
		{
			LoadInlineScript(script.content, script.path, script.line);
		}
		else
		{
			LoadExternalScript(script.path);
		}
	}

	// Update properties so that e.g. visibility status can be queried properly immediately.
	body->UpdateProperties();
}

// Returns the document's context.
Context* Document::GetContext()
{
	return context;
}

const String& Document::GetSourceURL() const
{
	return source_url;
}

// Sets the style sheet this document, and all of its children, uses.
void Document::SetStyleSheet(SharedPtr<StyleSheet> _style_sheet)
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
const SharedPtr<StyleSheet>& Document::GetStyleSheet() const
{
	return style_sheet;
}

void Document::Show() {
	GetContext()->SetFocus(this);
	body->DispatchEvent(EventId::Show, Dictionary());
}

void Document::Hide() {
	body->DispatchEvent(EventId::Hide, Dictionary());
	GetContext()->SetFocus(nullptr);
}

// Close this document
void Document::Close()
{
	if (context != nullptr)
		context->UnloadDocument(this);
}

ElementPtr Document::CreateElement(const String& name)
{
	ElementPtr element(new Element(this, name));
	return element;
}

// Create a text element.
TextPtr Document::CreateTextNode(const String& str)
{
	TextPtr text(new ElementText(this, str));
	if (!text)
	{
		Log::Message(Log::LT_ERROR, "Failed to create text element, instancer didn't return a derivative of ElementText.");
		return nullptr;
	}
	return text;
}

// Default load inline script implementation
void Document::LoadInlineScript(const String& content, const String& source_path, int source_line)
{
	PluginRegistry::NotifyLoadInlineScript(this, content, source_path, source_line);
}

// Default load external script implementation
void Document::LoadExternalScript(const String& source_path)
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

using ElementObserverList = Vector< ObserverPtr<Element> >;

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
	static const String property_names[] = {
		"ctrlKey",
		"shiftKey",
		"altKey",
		"metaKey",
	};
	for (int i = 0; i < sizeof(property_names) /sizeof(property_names[0]); ++i) {
		parameters[property_names[i]] = (int)((key_modifier_state & (1 << i)) > 0);
	}
}

static void GenerateMouseEventParameters(Dictionary& parameters, const Point& mouse_position, int button_index = -1) {
	parameters.reserve(3);
	parameters["x"] = mouse_position.x;
	parameters["y"] = mouse_position.y;
	if (button_index >= 0)
		parameters["button"] = button_index;
}

static void GenerateDragEventParameters(Dictionary& parameters, Element* drag) {
	parameters["drag_element"] = (void*)drag;
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

void Document::ProcessMouseMove(int x, int y, int key_modifier_state) {
	// Check whether the mouse moved since the last event came through.
	Point old_mouse_position = mouse_position;
	bool mouse_moved = (x != mouse_position.x) || (y != mouse_position.y);
	if (mouse_moved) {
		mouse_position.x = x;
		mouse_position.y = y;
	}

	// Generate the parameters for the mouse events (there could be a few!).
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	Dictionary drag_parameters;
	GenerateMouseEventParameters(drag_parameters, mouse_position);
	GenerateDragEventParameters(drag_parameters, drag);
	GenerateKeyModifierEventParameters(drag_parameters, key_modifier_state);

	// Update the current hover chain. This will send all necessary 'onmouseout', 'onmouseover', 'ondragout' and
	// 'ondragover' messages.
	UpdateHoverChain(parameters, drag_parameters, old_mouse_position);

	// Dispatch any 'onmousemove' events.
	if (mouse_moved) {
		if (hover) {
			hover->DispatchEvent(EventId::Mousemove, parameters);

			if (drag_hover && drag_verbose)
				drag_hover->DispatchEvent(EventId::Dragmove, drag_parameters);
		}
	}
}

void Document::ProcessMouseButtonDown(int button_index, int key_modifier_state) {
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position, button_index);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	if (button_index == 0)
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

			double click_time = GetSystemInterface()->GetElapsedTime();

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

		if (propagate)
		{
			// Traverse down the hierarchy of the newly focused element (if any), and see if we can begin dragging it.
			drag_started = false;
			drag = hover;
			while (drag)
			{
				Style::Drag drag_style = Style::Drag::None;
				switch (drag_style)
				{
				case Style::Drag::None:		drag = drag->GetParentNode(); continue;
				case Style::Drag::Block:	drag = nullptr; continue;
				default: drag_verbose = (drag_style == Style::Drag::DragDrop || drag_style == Style::Drag::Clone);
				}

				break;
			}
		}
	}
	else
	{
		// Not the primary mouse button, so we're not doing any special processing.
		if (hover)
			hover->DispatchEvent(EventId::Mousedown, parameters);
	}
}

void Document::ProcessMouseButtonUp(int button_index, int key_modifier_state) {
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position, button_index);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	// Process primary click.
	if (button_index == 0)
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

		if (drag)
		{
			if (drag_started)
			{
				Dictionary drag_parameters;
				GenerateMouseEventParameters(drag_parameters, mouse_position);
				GenerateDragEventParameters(drag_parameters, drag);
				GenerateKeyModifierEventParameters(drag_parameters, key_modifier_state);

				if (drag_hover)
				{
					if (drag_verbose)
					{
						drag_hover->DispatchEvent(EventId::Dragdrop, drag_parameters);
						// User may have removed the element, do an extra check.
						if (drag_hover)
							drag_hover->DispatchEvent(EventId::Dragout, drag_parameters);
					}
				}

				if (drag)
					drag->DispatchEvent(EventId::Dragend, drag_parameters);

				ReleaseDragClone();
			}

			drag = nullptr;
			drag_hover = nullptr;
			drag_hover_chain.clear();

			// We may have changes under our mouse, this ensures that the hover chain is properly updated
			ProcessMouseMove(mouse_position.x, mouse_position.y, key_modifier_state);
		}
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

	// Send out drag events.
	if (drag)
	{
		if (mouse_position != old_mouse_position)
		{
			if (!drag_started)
			{
				Dictionary drag_start_parameters = drag_parameters;
				GenerateMouseEventParameters(drag_start_parameters, old_mouse_position);
				drag->DispatchEvent(EventId::Dragstart, drag_start_parameters);
				drag_started = true;
				if (Style::Drag::None == Style::Drag::Clone)
				{
					// Clone the element and attach it to the mouse cursor.
					CreateDragClone(drag);
				}
			}

			drag->DispatchEvent(EventId::Drag, drag_parameters);
		}
	}

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

	// Send out drag events.
	if (drag)
	{
		drag_hover = body->GetElementAtPoint(position, drag);

		ElementSet new_drag_hover_chain;
		element = drag_hover;
		while (element != nullptr)
		{
			new_drag_hover_chain.insert(element);
			element = element->GetParentNode();
		}

		if (drag_started &&
			drag_verbose)
		{
			// Send out ondragover and ondragout events as appropriate.
			SendEvents(drag_hover_chain, new_drag_hover_chain, EventId::Dragout, drag_parameters);
			SendEvents(new_drag_hover_chain, drag_hover_chain, EventId::Dragover, drag_parameters);
		}

		drag_hover_chain.swap(new_drag_hover_chain);
	}

	// Swap the new chain in.
	hover_chain.swap(new_hover_chain);
}

void Document::CreateDragClone(Element* element) {
	if (!cursor_proxy)
	{
		Log::Message(Log::LT_ERROR, "Unable to create drag clone, no cursor proxy document.");
		return;
	}

	ReleaseDragClone();

	// Instance the drag clone.
	ElementPtr clone(new Element(element->GetOwnerDocument(), element->GetTagName()));
	clone->SetAttributes(element->GetAttributes());
	clone->SetInnerRML(element->GetInnerRML());
	if (!clone)
	{
		Log::Message(Log::LT_ERROR, "Unable to duplicate drag clone.");
		return;
	}

	drag_clone = clone.get();

	// Append the clone to the cursor proxy element.
	cursor_proxy->AppendChild(std::move(clone));

	// Set the style sheet on the cursor proxy.
	//TODO static_cast<Document&>(*cursor_proxy).SetStyleSheet(element->GetStyleSheet());

	// Set all the required properties and pseudo-classes on the clone.
	drag_clone->SetPseudoClass("drag", true);
	//drag_clone->SetPropertyImmediate(PropertyId::Position, Property(Style::Position::Absolute));
	//drag_clone->SetPropertyImmediate(PropertyId::Left, Property(element->GetOffset().x - mouse_position.x, Property::PX));
	//drag_clone->SetPropertyImmediate(PropertyId::Top, Property(element->GetOffset().y - mouse_position.y, Property::PX));
}

void Document::ReleaseDragClone() {
	if (drag_clone)
	{
		cursor_proxy->RemoveChild(drag_clone);
		drag_clone = nullptr;
	}
}

void Document::OnElementDetach(Element* element) {
	auto it_hover = hover_chain.find(element);
	if (it_hover != hover_chain.end())
	{
		Dictionary parameters;
		GenerateMouseEventParameters(parameters, mouse_position);
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

	if (drag)
	{
		auto it = drag_hover_chain.find(element);
		if (it != drag_hover_chain.end())
		{
			drag_hover_chain.erase(it);

			if (drag_hover == element)
				drag_hover = nullptr;
		}

		if (drag == element)
		{
			// The dragged element is being removed, silently cancel the drag operation
			if (drag_started)
				ReleaseDragClone();

			drag = nullptr;
			drag_hover = nullptr;
			drag_hover_chain.clear();
		}
	}
}

DataModelConstructor Document::CreateDataModel(const String& name) {
	if (!data_type_register)
		data_type_register = MakeUnique<DataTypeRegister>();

	auto result = data_models.emplace(name, MakeUnique<DataModel>(data_type_register->GetTransformFuncRegister()));
	bool inserted = result.second;
	if (inserted)
		return DataModelConstructor(result.first->second.get(), data_type_register.get());

	Log::Message(Log::LT_ERROR, "Data model name '%s' already exists.", name.c_str());
	return DataModelConstructor();
}

DataModelConstructor Document::GetDataModel(const String& name) {
	if (data_type_register)
	{
		if (DataModel* model = GetDataModelPtr(name))
			return DataModelConstructor(model, data_type_register.get());
	}

	Log::Message(Log::LT_ERROR, "Data model name '%s' could not be found.", name.c_str());
	return DataModelConstructor();
}

bool Document::RemoveDataModel(const String& name) {
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

DataModel* Document::GetDataModelPtr(const String& name) const {
	auto it = data_models.find(name);
	if (it != data_models.end())
		return it->second.get();
	return nullptr;
}

void Document::SetDimensions(const Size& _dimensions) {
	if (dimensions != _dimensions) {
		dimensions = _dimensions;
		body->DispatchEvent(EventId::Resize, Dictionary());
	}
}

void Document::Update() {
	body->Update();
	body->GetLayout().CalculateLayout(dimensions);
	body->UpdateLayout();
}

void Document::Render() {
	body->OnRender();
}

} // namespace Rml
