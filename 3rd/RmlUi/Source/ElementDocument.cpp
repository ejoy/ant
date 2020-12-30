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

#include "../Include/RmlUi/ElementDocument.h"
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/SystemInterface.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "DocumentHeader.h"
#include "ElementStyle.h"
#include "EventDispatcher.h"
#include "StreamFile.h"
#include "StyleSheetFactory.h"
#include "XMLParseTools.h"
#include "DataModel.h"
#include "PluginRegistry.h"
#include <set>

static constexpr float DOUBLE_CLICK_TIME = 0.5f;     // [s]
static constexpr float DOUBLE_CLICK_MAX_DIST = 3.f;  // [dp]

namespace Rml {

ElementDocument::ElementDocument(const String& tag) : Element(tag)
{
	style_sheet = nullptr;
	context = nullptr;
	SetOwnerDocument(this);
	SetProperty(PropertyId::Position, Property(Style::Position::Absolute));
}

ElementDocument::~ElementDocument() {
	for (ElementPtr& child : children) {
		child->SetOwnerDocument(nullptr);
		child->SetParent(nullptr);
	}
	children.clear();
}

void ElementDocument::ProcessHeader(const DocumentHeader* header)
{
	// Store the source address that we came from
	source_url = header->source;

	// Set the title to the document title.
	title = header->title;

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

	// Hide this document.
	SetProperty(PropertyId::Visibility, Property(Style::Visibility::Hidden));

	// Update properties so that e.g. visibility status can be queried properly immediately.
	UpdateProperties();
}

// Returns the document's context.
Context* ElementDocument::GetContext()
{
	return context;
}

// Sets the document's title.
void ElementDocument::SetTitle(const String& _title)
{
	title = _title;
}

const String& ElementDocument::GetTitle() const
{
	return title;
}

const String& ElementDocument::GetSourceURL() const
{
	return source_url;
}

// Sets the style sheet this document, and all of its children, uses.
void ElementDocument::SetStyleSheet(SharedPtr<StyleSheet> _style_sheet)
{
	if (style_sheet == _style_sheet)
		return;

	style_sheet = std::move(_style_sheet);
	
	if (style_sheet)
	{
		style_sheet->BuildNodeIndex();
	}

	GetStyle()->DirtyDefinition();
}

// Returns the document's style sheet.
const SharedPtr<StyleSheet>& ElementDocument::GetStyleSheet() const
{
	return style_sheet;
}

void ElementDocument::Show() {
	// Set to visible and switch focus if necessary
	SetProperty(PropertyId::Visibility, Property(Style::Visibility::Visible));
	
	// We should update the document now, otherwise the focusing methods below do not think we are visible
	// If this turns out to be slow, the more performant approach is just to compute the new visibility property
	UpdateDocument();

	DispatchEvent(EventId::Show, Dictionary());
	GetContext()->SetFocus(this);
}

void ElementDocument::Hide()
{
	SetProperty(PropertyId::Visibility, Property(Style::Visibility::Hidden));

	// We should update the document now, so that the (un)focusing will get the correct visibility
	UpdateDocument();

	DispatchEvent(EventId::Hide, Dictionary());
}

// Close this document
void ElementDocument::Close()
{
	if (context != nullptr)
		context->UnloadDocument(this);
}

ElementPtr ElementDocument::CreateElement(const String& name)
{
	ElementPtr element(new Element(name));
	element->SetOwnerDocument(this);
	return element;
}

// Create a text element.
ElementPtr ElementDocument::CreateTextNode(const String& text)
{
	ElementPtr element(new ElementText("#text"));
	element->SetOwnerDocument(this);
	ElementText* element_text = dynamic_cast< ElementText* >(element.get());
	if (!element_text)
	{
		Log::Message(Log::LT_ERROR, "Failed to create text element, instancer didn't return a derivative of ElementText.");
		return nullptr;
	}
	
	// Set the text
	element_text->SetText(text);

	return element;
}

// Default load inline script implementation
void ElementDocument::LoadInlineScript(const String& content, const String& source_path, int source_linbe)
{
	PluginRegistry::NotifyLoadInlineScript(this, content, source_path, source_linbe);
}

// Default load external script implementation
void ElementDocument::LoadExternalScript(const String& source_path)
{
	PluginRegistry::NotifyLoadExternalScript(this, source_path);
}

// Updates the document, including its layout
void ElementDocument::UpdateDocument()
{
	const float dp_ratio = (context ? context->GetDensityIndependentPixelRatio() : 1.0f);
	Update(dp_ratio);
	UpdateLayout();
}

void ElementDocument::UpdateDataModel(bool clear_dirty_variables) {
	for (auto& data_model : data_models) {
		data_model.second->Update(true);
	}
}

// Updates the layout if necessary.
void ElementDocument::UpdateLayout()
{
	if (dirty_layout) {
		GetLayout().CalculateLayout(GetClientWidth(), GetClientHeight());
		UpdateChildrenBounds();
	}
}

void ElementDocument::DirtyLayout()
{
	dirty_layout = true;
}

void ElementDocument::DirtyDpProperties()
{
	GetStyle()->DirtyPropertiesWithUnitRecursive(Property::DP);
}

// Repositions the document if necessary.
void ElementDocument::OnPropertyChange(const PropertyIdSet& changed_properties)
{
	Element::OnPropertyChange(changed_properties);

	// If the document's font-size has been changed, we need to dirty all rem properties.
	if (changed_properties.Contains(PropertyId::FontSize))
		GetStyle()->DirtyPropertiesWithUnitRecursive(Property::REM);
}

void ElementDocument::OnResize()
{
}

enum class CanFocus { Yes, No, NoAndNoChildren };
static CanFocus CanFocusElement(Element* element)
{
	if (element->IsPseudoClassSet("disabled"))
		return CanFocus::NoAndNoChildren;

	if (!element->IsVisible())
		return CanFocus::NoAndNoChildren;

	return CanFocus::Yes;
	//return CanFocus::No;
}

// Find the next element to focus, starting at the current element
//
// This algorithm is quite sneaky, I originally thought a depth first search would
// work, but it appears not. What is required is to cut the tree in half along the nodes
// from current_element up the root and then either traverse the tree in a clockwise or
// anticlock wise direction depending if you're searching forward or backward respectively
Element* ElementDocument::FindNextTabElement(Element* current_element, bool forward)
{
	// If we're searching forward, check the immediate children of this node first off
	if (forward)
	{
		for (int i = 0; i < current_element->GetNumChildren(); i++)
			if (Element* result = SearchFocusSubtree(current_element->GetChild(i), forward))
				return result;
	}

	// Now walk up the tree, testing either the bottom or top
	// of the tree, depending on whether we're going forwards
	// or backwards respectively
	//
	// If we make it all the way up to the document, then
	// we search the entire tree (to loop back round)
	bool search_enabled = false;
	Element* document = current_element->GetOwnerDocument();
	Element* child = current_element;
	Element* parent = current_element->GetParentNode();
	while (child != document)
	{
		for (int i = 0; i < parent->GetNumChildren(); i++)
		{
			// Calculate index into children
			int child_index = i;
			if (!forward)
				child_index = parent->GetNumChildren() - i - 1;
			Element* search_child = parent->GetChild(child_index);

			// Do a search if its enabled
			if (search_enabled)
				if(Element* result = SearchFocusSubtree(search_child, forward))
					return result;

			// Enable searching when we reach the child.
			if (search_child == child)
				search_enabled = true;
		}

		// Advance up the tree
		child = parent;
		parent = parent->GetParentNode();

		if (parent == document)
		{
			// When we hit the top, see if we can focus the document first.
			if (CanFocusElement(document) == CanFocus::Yes)
				return document;
			
			// Otherwise, search the entire tree to loop back around.
			search_enabled = true;
		}
		else
		{
			// Prepare for the next iteration by disabling searching.
			search_enabled = false;
		}
	}

	return nullptr;
}

Element* ElementDocument::SearchFocusSubtree(Element* element, bool forward)
{
	CanFocus can_focus = CanFocusElement(element);
	if (can_focus == CanFocus::Yes)
		return element;
	else if (can_focus == CanFocus::NoAndNoChildren)
		return nullptr;

	// Check all children
	for (int i = 0; i < element->GetNumChildren(); i++)
	{
		int child_index = i;
		if (!forward)
			child_index = element->GetNumChildren() - i - 1;
		if (Element * result = SearchFocusSubtree(element->GetChild(child_index), forward))
			return result;
	}

	return nullptr;
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

static void GenerateMouseEventParameters(Dictionary& parameters, const Vector2i& mouse_position, int button_index = -1) {
	parameters.reserve(3);
	parameters["x"] = mouse_position.x;
	parameters["y"] = mouse_position.y;
	if (button_index >= 0)
		parameters["button"] = button_index;
}

static void GenerateDragEventParameters(Dictionary& parameters, Element* drag) {
	parameters["drag_element"] = (void*)drag;
}

bool ElementDocument::ChangeFocus(Element* new_focus) {
	RMLUI_ASSERT(new_focus);
	ElementSet old_chain;
	ElementSet new_chain;
	Element* old_focus = focus;

	Element* element = old_focus;
	while (element) {
		old_chain.insert(element);
		element = element->GetParentNode();
	}
	element = new_focus;
	while (element) {
		new_chain.insert(element);
		element = element->GetParentNode();
	}

	Dictionary parameters;
	SendEvents(old_chain, new_chain, EventId::Blur, parameters);
	SendEvents(new_chain, old_chain, EventId::Focus, parameters);
	focus = new_focus;
	return true;
}

Element* ElementDocument::GetFocus() const {
	return focus;
}

bool ElementDocument::ProcessKeyDown(Input::KeyIdentifier key, int key_modifier_state) {
	Dictionary parameters;
	GenerateKeyEventParameters(parameters, key);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	if (focus) {
		return focus->DispatchEvent(EventId::Keydown, parameters);
	}
	return DispatchEvent(EventId::Keydown, parameters);
}

bool ElementDocument::ProcessKeyUp(Input::KeyIdentifier key, int key_modifier_state) {
	Dictionary parameters;
	GenerateKeyEventParameters(parameters, key);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);
	if (focus) {
		return focus->DispatchEvent(EventId::Keyup, parameters);
	}
	return DispatchEvent(EventId::Keyup, parameters);
}

void ElementDocument::ProcessMouseMove(int x, int y, int key_modifier_state) {
	// Check whether the mouse moved since the last event came through.
	Vector2i old_mouse_position = mouse_position;
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

static Element* FindFocusElement(Element* element)
{
	ElementDocument* owner_document = element->GetOwnerDocument();
	if (!owner_document || owner_document->GetComputedValues().focus == Style::Focus::None)
		return nullptr;

	while (element && element->GetComputedValues().focus == Style::Focus::None)
	{
		element = element->GetParentNode();
	}

	return element;
}

void ElementDocument::ProcessMouseButtonDown(int button_index, int key_modifier_state) {
	Dictionary parameters;
	GenerateMouseEventParameters(parameters, mouse_position, button_index);
	GenerateKeyModifierEventParameters(parameters, key_modifier_state);

	if (button_index == 0)
	{
		Element* new_focus = hover;

		// Set the currently hovered element to focus if it isn't already the focus.
		if (hover)
		{
			new_focus = FindFocusElement(hover);
			//if (new_focus && new_focus != focus)
			{
				if (!new_focus->Focus())
					return;
			}
		}

		// Save the just-pressed-on element as the pressed element.
		active = new_focus;

		bool propagate = true;

		// Call 'onmousedown' on every item in the hover chain, and copy the hover chain to the active chain.
		if (hover)
			propagate = hover->DispatchEvent(EventId::Mousedown, parameters);

		if (propagate)
		{
			// Check for a double-click on an element; if one has occured, we send the 'dblclick' event to the hover
			// element. If not, we'll start a timer to catch the next one.
			float mouse_distance_squared = float((mouse_position - last_click_mouse_position).SquaredMagnitude());
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
				Style::Drag drag_style = drag->GetComputedValues().drag;
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

void ElementDocument::ProcessMouseButtonUp(int button_index, int key_modifier_state) {
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
		if (hover && active && active == FindFocusElement(hover))
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

void ElementDocument::ProcessMouseWheel(float wheel_delta, int key_modifier_state) {
	if (hover) {
		Dictionary scroll_parameters;
		GenerateKeyModifierEventParameters(scroll_parameters, key_modifier_state);
		scroll_parameters["wheel_delta"] = wheel_delta;

		hover->DispatchEvent(EventId::Mousescroll, scroll_parameters);
	}
}

void ElementDocument::UpdateHoverChain(const Dictionary& parameters, const Dictionary& drag_parameters, const Vector2i& old_mouse_position) {
	Vector2f position((float)mouse_position.x, (float)mouse_position.y);

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
				if (drag->GetComputedValues().drag == Style::Drag::Clone)
				{
					// Clone the element and attach it to the mouse cursor.
					CreateDragClone(drag);
				}
			}

			drag->DispatchEvent(EventId::Drag, drag_parameters);
		}
	}

	hover = GetElementAtPoint(position);

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
		drag_hover = GetElementAtPoint(position, drag);

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

void ElementDocument::CreateDragClone(Element* element) {
	if (!cursor_proxy)
	{
		Log::Message(Log::LT_ERROR, "Unable to create drag clone, no cursor proxy document.");
		return;
	}

	ReleaseDragClone();

	// Instance the drag clone.
	ElementPtr element_drag_clone = element->Clone();
	if (!element_drag_clone)
	{
		Log::Message(Log::LT_ERROR, "Unable to duplicate drag clone.");
		return;
	}

	drag_clone = element_drag_clone.get();

	// Append the clone to the cursor proxy element.
	cursor_proxy->AppendChild(std::move(element_drag_clone));

	// Set the style sheet on the cursor proxy.
	static_cast<ElementDocument&>(*cursor_proxy).SetStyleSheet(element->GetStyleSheet());

	// Set all the required properties and pseudo-classes on the clone.
	drag_clone->SetPseudoClass("drag", true);
	drag_clone->SetProperty(PropertyId::Position, Property(Style::Position::Absolute));
	drag_clone->SetProperty(PropertyId::Left, Property(element->GetAbsoluteLeft() - element->GetLayout().GetEdge(Layout::MARGIN, Layout::LEFT) - mouse_position.x, Property::PX));
	drag_clone->SetProperty(PropertyId::Top, Property(element->GetAbsoluteTop() - element->GetLayout().GetEdge(Layout::MARGIN, Layout::TOP) - mouse_position.y, Property::PX));
}

void ElementDocument::ReleaseDragClone() {
	if (drag_clone)
	{
		cursor_proxy->RemoveChild(drag_clone);
		drag_clone = nullptr;
	}
}

void ElementDocument::OnElementDetach(Element* element) {
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

DataModelConstructor ElementDocument::CreateDataModel(const String& name) {
	if (!data_type_register)
		data_type_register = MakeUnique<DataTypeRegister>();

	auto result = data_models.emplace(name, MakeUnique<DataModel>(data_type_register->GetTransformFuncRegister()));
	bool inserted = result.second;
	if (inserted)
		return DataModelConstructor(result.first->second.get(), data_type_register.get());

	Log::Message(Log::LT_ERROR, "Data model name '%s' already exists.", name.c_str());
	return DataModelConstructor();
}

DataModelConstructor ElementDocument::GetDataModel(const String& name) {
	if (data_type_register)
	{
		if (DataModel* model = GetDataModelPtr(name))
			return DataModelConstructor(model, data_type_register.get());
	}

	Log::Message(Log::LT_ERROR, "Data model name '%s' could not be found.", name.c_str());
	return DataModelConstructor();
}

bool ElementDocument::RemoveDataModel(const String& name) {
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

DataModel* ElementDocument::GetDataModelPtr(const String& name) const {
	auto it = data_models.find(name);
	if (it != data_models.end())
		return it->second.get();
	return nullptr;
}

} // namespace Rml
