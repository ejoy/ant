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

  
#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/Dictionary.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Transform.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "DataModel.h"
#include "ElementAnimation.h"
#include "ElementBackgroundBorder.h"
#include "ElementDefinition.h"
#include "ElementStyle.h"
#include "EventDispatcher.h"
#include "EventSpecification.h"
#include "ElementBackgroundImage.h"
#include "PluginRegistry.h"
#include "PropertiesIterator.h"
#include "StyleSheetParser.h"
#include "StyleSheetNode.h"
#include <algorithm>
#include <cmath>
#include <yoga/YGNode.h>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtx/transform.hpp>

namespace Rml {

struct ElementMeta {
	ElementMeta(Element* el) : event_dispatcher(el), style(el) {}
	EventDispatcher event_dispatcher;
	ElementStyle style;
	Style::ComputedValues computed_values;
};

Element::Element(Document* owner, const std::string& tag)
	: owner_document(owner)
	, tag(tag)
	, dirty_perspective(false)
	, dirty_animation(false)
	, dirty_transition(false)
{
	RMLUI_ASSERT(tag == StringUtilities::ToLower(tag));
	parent = nullptr;
	z_index = 0;
	stacking_context_dirty = true;
	structure_dirty = false;
	meta = new ElementMeta(this);
	data_model = nullptr;
}

Element::~Element() {
	RMLUI_ASSERT(parent == nullptr);
	//GetOwnerDocument()->OnElementDetach(this);
	SetDataModel(nullptr);
	for (ElementPtr& child : children) {
		child->SetParent(nullptr);
	}
	delete meta;
}

void Element::Update() {
	UpdateStructure();
	HandleTransitionProperty();
	HandleAnimationProperty();
	AdvanceAnimations();
	UpdateProperties();
	if (dirty_animation) {
		HandleAnimationProperty();
		AdvanceAnimations();
		UpdateProperties();
	}
	UpdateStackingContext();
	for (auto& child : children) {
		child->Update();
	}
}

void Element::UpdateProperties() {
	meta->style.UpdateDefinition();
	if (meta->style.AnyPropertiesDirty()) {
		PropertyIdSet dirty_properties = meta->style.ComputeValues(meta->computed_values);
		if (!dirty_properties.Empty()) {
			OnChange(dirty_properties);
		}
	}
}

void Element::OnRender() {
	if (!IsVisible()) {
		return;
	}
	UpdateTransform();
	UpdatePerspective();
	UpdateClip();
	UpdateGeometry();

	size_t i = 0;
	for (; i < stacking_context.size() && stacking_context[i]->GetZIndex() < 0; ++i) {
		stacking_context[i]->OnRender();
	}
	SetRednerStatus();
	if (geometry_border) {
		geometry_border->Render();
	}
	if (geometry_image) {
		geometry_image->Render();
	}
	for (; i < stacking_context.size(); ++i) {
		stacking_context[i]->OnRender();
	}
}

void Element::SetClass(const std::string& class_name, bool activate)
{
	meta->style.SetClass(class_name, activate);
}

bool Element::IsClassSet(const std::string& class_name) const
{
	return meta->style.IsClassSet(class_name);
}

void Element::SetClassNames(const std::string& class_names)
{
	SetAttribute("class", class_names);
}

std::string Element::GetClassNames() const
{
	return meta->style.GetClassNames();
}

const std::shared_ptr<StyleSheet>& Element::GetStyleSheet() const
{
	if (Document * document = GetOwnerDocument())
		return document->GetStyleSheet();
	static std::shared_ptr<StyleSheet> null_style_sheet;
	return null_style_sheet;
}

const ElementDefinition* Element::GetDefinition()
{
	return meta->style.GetDefinition();
}

std::string Element::GetAddress(bool include_pseudo_classes, bool include_parents) const
{
	std::string address(tag);

	if (!id.empty())
	{
		address += "#";
		address += id;
	}

	std::string classes = meta->style.GetClassNames();
	if (!classes.empty())
	{
		classes = StringUtilities::Replace(classes, ' ', '.');
		address += ".";
		address += classes;
	}

	if (include_pseudo_classes)
	{
		const PseudoClassList& pseudo_classes = meta->style.GetActivePseudoClasses();		
		for (PseudoClassList::const_iterator i = pseudo_classes.begin(); i != pseudo_classes.end(); ++i)
		{
			address += ":";
			address += (*i);
		}
	}

	if (include_parents && parent)
	{
		address += " < ";
		return address + parent->GetAddress(include_pseudo_classes, true);
	}
	else
		return address;
}

bool Element::IsPointWithinElement(Point point) {
	return Project(point) && Rect { {}, GetMetrics().frame.size }.Contains(point);
}

float Element::GetZIndex() const {
	return z_index;
}

float Element::GetFontSize() const {
	return font_size;
}

static float ComputeFontsize(const Property* property, Element* element) {
	if (property->unit == Property::PERCENT || property->unit == Property::EM) {
		float fontSize = 16.f;
		Element* parent = element->GetParentNode();
		if (parent) {
			fontSize = parent->GetFontSize();
		}
		if (property->unit == Property::PERCENT) {
			return fontSize * 0.01f * property->Get<float>();
		}
		return fontSize * property->Get<float>();
	}
	if (property->unit == Property::REM) {
		if (element == element->GetOwnerDocument()->body.get()) {
			return property->Get<float>() * 16;
		}
	}
	return ComputeProperty(property, element);
}

bool Element::UpdataFontSize() {
	float new_size = font_size;
	if (auto p = meta->style.GetLocalProperty(PropertyId::FontSize))
		new_size = ComputeFontsize(p, this);
	else if (parent) {
		new_size = parent->GetFontSize();
	}
	if (new_size != font_size) {
		font_size = new_size;
		return true;
	}
	return false;
}

float Element::GetOpacity() {
	const Property* property = GetProperty(PropertyId::Opacity);
	return property->Get<float>();
}

bool Element::SetProperty(const std::string& name, const std::string& value) {
	PropertyDictionary properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, value)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value.c_str());
		return false;
	}
	for (auto& property : properties.GetProperties()) {
		if (!meta->style.SetProperty(property.first, property.second))
			return false;
	}
	return true;
}

bool Element::SetPropertyImmediate(const std::string& name, const std::string& value) {
	PropertyDictionary properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, value)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value.c_str());
		return false;
	}
	for (auto& property : properties.GetProperties()) {
		if (!meta->style.SetPropertyImmediate(property.first, property.second))
			return false;
	}
	return true;
}

bool Element::SetProperty(PropertyId id, const Property& property) {
	return meta->style.SetProperty(id, property);
}

bool Element::SetPropertyImmediate(PropertyId id, const Property& property) {
	return meta->style.SetPropertyImmediate(id, property);
}

void Element::RemoveProperty(const std::string& name)
{
	meta->style.RemoveProperty(StyleSheetSpecification::GetPropertyId(name));
}

void Element::RemoveProperty(PropertyId id)
{
	meta->style.RemoveProperty(id);
}

const Property* Element::GetProperty(const std::string& name)
{
	return meta->style.GetProperty(StyleSheetSpecification::GetPropertyId(name));
}

const Property* Element::GetProperty(PropertyId id)
{
	return meta->style.GetProperty(id);
}

bool Element::Project(Point& point) const noexcept {
	if (!inv_transform) {
		have_inv_transform = 0.f != glm::determinant(transform);
		if (have_inv_transform) {
			inv_transform = std::make_unique<glm::mat4x4>(glm::inverse(transform));
		}
	}
	if (!have_inv_transform) {
		return false;
	}

	glm::vec4 window_points[2] = { { point.x, point.y, -10, 1}, { point.x, point.y, 10, 1 } };
	window_points[0] = *inv_transform * window_points[0];
	window_points[1] = *inv_transform * window_points[1];
	glm::vec3 local_points[2] = {
		window_points[0] / window_points[0].w,
		window_points[1] / window_points[1].w
	};
	glm::vec3 ray = local_points[1] - local_points[0];
	if (std::fabs(ray.z) > 1.0f) {
		float t = -local_points[0].z / ray.z;
		glm::vec3 p = local_points[0] + ray * t;
		point = Point(p.x, p.y);
		return true;
	}
	return false;
}

void Element::SetPseudoClass(const std::string& pseudo_class, bool activate)
{
	meta->style.SetPseudoClass(pseudo_class, activate);
}

bool Element::IsPseudoClassSet(const std::string& pseudo_class) const
{
	return meta->style.IsPseudoClassSet(pseudo_class);
}

bool Element::ArePseudoClassesSet(const PseudoClassList& pseudo_classes) const
{
	for (PseudoClassList::const_iterator i = pseudo_classes.begin(); i != pseudo_classes.end(); ++i)
	{
		if (!IsPseudoClassSet(*i))
			return false;
	}

	return true;
}

const PseudoClassList& Element::GetActivePseudoClasses() const
{
	return meta->style.GetActivePseudoClasses();
}

const std::string* Element::GetAttribute(const std::string& name) const
{
	auto it = attributes.find(name);
	if (it == attributes.end()) {
		return nullptr;
	}
	return &it->second;
}

bool Element::HasAttribute(const std::string& name) const
{
	return attributes.find(name) != attributes.end();
}

void Element::RemoveAttribute(const std::string& name)
{
	auto it = attributes.find(name);
	if (it != attributes.end())
	{
		attributes.erase(it);

		ElementAttributes changed_attributes;
		changed_attributes.emplace(name, std::string());
		OnAttributeChange(changed_attributes);
	}
}

Context* Element::GetContext() const
{
	if (Document* document = GetOwnerDocument())
		return document->GetContext();
	return nullptr;
}

void Element::SetAttributes(const ElementAttributes& _attributes)
{
	attributes.reserve(attributes.size() + _attributes.size());
	for (auto& pair : _attributes)
		attributes[pair.first] = pair.second;

	OnAttributeChange(_attributes);
}

int Element::GetNumAttributes() const
{
	return (int)attributes.size();
}

const std::string& Element::GetTagName() const
{
	return tag;
}

const std::string& Element::GetId() const
{
	return id;
}

void Element::SetId(const std::string& _id)
{
	SetAttribute("id", _id);
}

ElementStyle* Element::GetStyle() const
{
	return &meta->style;
}

Document* Element::GetOwnerDocument() const {
	return owner_document;
}

Element* Element::GetChild(int index) const {
	if (index < 0 || index >= (int) children.size())
		return nullptr;

	return children[index].get();
}

int Element::GetNumChildren() const {
	return (int)children.size();
}

void Element::SetInnerRML(const std::string& rml) {
	//while ((int) children.size() > 0)
	//	RemoveChild(children.front().get());
	//if (rml.empty()) {
	//	return;
	//}
	//
	//if (std::all_of(rml.begin(), rml.end(), &StringUtilities::IsWhitespace))
	//	return;
	//auto stream = std::make_unique<StreamMemory>(rml.size() + 32);
	//Context* context = parent->GetContext();
	//std::string open_tag = "<" + tag + ">";
	//std::string close_tag = "</" + tag + ">";
	//stream->Write(open_tag.c_str(), open_tag.size());
	//stream->Write(rml);
	//stream->Write(close_tag.c_str(), close_tag.size());
	//stream->Seek(0, SEEK_SET);
	//XMLParser parser(parent);
	//parser.Parse(stream.get());
}

void Element::AddEventListener(const std::string& event, EventListener* listener, bool in_capture_phase) {
	EventId id = EventSpecificationInterface::GetIdOrInsert(event);
	meta->event_dispatcher.AttachEvent(id, listener, in_capture_phase);
}

void Element::AddEventListener(EventId id, EventListener* listener, bool in_capture_phase) {
	meta->event_dispatcher.AttachEvent(id, listener, in_capture_phase);
}

void Element::RemoveEventListener(const std::string& event, EventListener* listener, bool in_capture_phase) {
	EventId id = EventSpecificationInterface::GetIdOrInsert(event);
	meta->event_dispatcher.DetachEvent(id, listener, in_capture_phase);
}

void Element::RemoveEventListener(EventId id, EventListener* listener, bool in_capture_phase)
{
	meta->event_dispatcher.DetachEvent(id, listener, in_capture_phase);
}

bool Element::DispatchEvent(const std::string& type, const Dictionary& parameters) {
	const EventSpecification& specification = EventSpecificationInterface::GetOrInsert(type);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, specification.interruptible, specification.bubbles, specification.default_action_phase);
}

bool Element::DispatchEvent(const std::string& type, const Dictionary& parameters, bool interruptible, bool bubbles) {
	const EventSpecification& specification = EventSpecificationInterface::GetOrInsert(type);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, interruptible, bubbles, specification.default_action_phase);
}

bool Element::DispatchEvent(EventId id, const Dictionary& parameters) {
	const EventSpecification& specification = EventSpecificationInterface::Get(id);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, specification.interruptible, specification.bubbles, specification.default_action_phase);
}

Element* Element::AppendChild(ElementPtr child) {
	RMLUI_ASSERT(child);
	Element* child_ptr = child.get();
	GetLayout().InsertChild(child->GetLayout(), (uint32_t)children.size());
	children.insert(children.end(), std::move(child));
	child_ptr->SetParent(this);
	DirtyStackingContext();
	DirtyStructure();
	return child_ptr;
}

Element* Element::InsertBefore(ElementPtr child, Element* adjacent_element) {
	RMLUI_ASSERT(child);
	size_t child_index = 0;
	bool found_child = false;
	if (adjacent_element)
	{
		for (child_index = 0; child_index < children.size(); child_index++)
		{
			if (children[child_index].get() == adjacent_element)
			{
				found_child = true;
				break;
			}
		}
	}

	Element* child_ptr = nullptr;

	if (found_child)
	{
		child_ptr = child.get();

		GetLayout().InsertChild(child->GetLayout(), (uint32_t)child_index);
		children.insert(children.begin() + child_index, std::move(child));
		child_ptr->SetParent(this);
		DirtyStackingContext();
		DirtyStructure();
	}
	else
	{
		child_ptr = AppendChild(std::move(child));
	}	

	return child_ptr;
}

ElementPtr Element::RemoveChild(Element* child) {
	size_t child_index = 0;

	for (auto itr = children.begin(); itr != children.end(); ++itr)
	{
		// Add the element to the delete list
		if (itr->get() == child)
		{
			Element* ancestor = child;

			ElementPtr detached_child = std::move(*itr);
			children.erase(itr);

			detached_child->SetParent(nullptr);

			GetLayout().RemoveChild(child->GetLayout());
			DirtyStackingContext();
			DirtyStructure();

			return detached_child;
		}

		child_index++;
	}

	return nullptr;
}

Element* Element::GetElementById(const std::string& id) {
	if (id == "#self")
		return this;
	else if (id == "#document")
		return GetOwnerDocument()->body.get();
	else if (id == "#parent")
		return this->parent;
	Element* search_root = GetOwnerDocument()->body.get();
	if (search_root == nullptr)
		search_root = this;
		
	// Breadth first search on elements for the corresponding id
	typedef std::queue<Element*> SearchQueue;
	SearchQueue search_queue;
	search_queue.push(search_root);

	while (!search_queue.empty())
	{
		Element* element = search_queue.front();
		search_queue.pop();
		
		if (element->GetId() == id)
		{
			return element;
		}
		
		for (int i = 0; i < element->GetNumChildren(); i++)
			search_queue.push(element->GetChild(i));
	}
	return nullptr;
}

void Element::GetElementsByTagName(ElementList& elements, const std::string& tag) {
	// Breadth first search on elements for the corresponding id
	typedef std::queue< Element* > SearchQueue;
	SearchQueue search_queue;
	for (int i = 0; i < GetNumChildren(); ++i)
		search_queue.push(GetChild(i));

	while (!search_queue.empty())
	{
		Element* element = search_queue.front();
		search_queue.pop();

		if (element->GetTagName() == tag)
			elements.push_back(element);

		for (int i = 0; i < element->GetNumChildren(); i++)
			search_queue.push(element->GetChild(i));
	}
}

void Element::GetElementsByClassName(ElementList& elements, const std::string& class_name)
{
	// Breadth first search on elements for the corresponding id
	typedef std::queue< Element* > SearchQueue;
	SearchQueue search_queue;
	for (int i = 0; i < GetNumChildren(); ++i)
		search_queue.push(GetChild(i));

	while (!search_queue.empty())
	{
		Element* element = search_queue.front();
		search_queue.pop();

		if (element->IsClassSet(class_name))
			elements.push_back(element);

		for (int i = 0; i < element->GetNumChildren(); i++)
			search_queue.push(element->GetChild(i));
	}
}

static Element* QuerySelectorMatchRecursive(const StyleSheetNodeListRaw& nodes, Element* element)
{
	for (int i = 0; i < element->GetNumChildren(); i++)
	{
		Element* child = element->GetChild(i);

		for (const StyleSheetNode* node : nodes)
		{
			if (node->IsApplicable(child, false))
				return child;
		}

		Element* matching_element = QuerySelectorMatchRecursive(nodes, child);
		if (matching_element)
			return matching_element;
	}

	return nullptr;
}

static void QuerySelectorAllMatchRecursive(ElementList& matching_elements, const StyleSheetNodeListRaw& nodes, Element* element)
{
	for (int i = 0; i < element->GetNumChildren(); i++)
	{
		Element* child = element->GetChild(i);

		for (const StyleSheetNode* node : nodes)
		{
			if (node->IsApplicable(child, false))
			{
				matching_elements.push_back(child);
				break;
			}
		}

		QuerySelectorAllMatchRecursive(matching_elements, nodes, child);
	}
}

Element* Element::QuerySelector(const std::string& selectors)
{
	StyleSheetNode root_node;
	StyleSheetNodeListRaw leaf_nodes = StyleSheetParser::ConstructNodes(root_node, selectors);

	if (leaf_nodes.empty())
	{
		Log::Message(Log::Level::Warning, "Query selector '%s' is empty. In element %s", selectors.c_str(), GetAddress().c_str());
		return nullptr;
	}

	return QuerySelectorMatchRecursive(leaf_nodes, this);
}

void Element::QuerySelectorAll(ElementList& elements, const std::string& selectors)
{
	StyleSheetNode root_node;
	StyleSheetNodeListRaw leaf_nodes = StyleSheetParser::ConstructNodes(root_node, selectors);

	if (leaf_nodes.empty())
	{
		Log::Message(Log::Level::Warning, "Query selector '%s' is empty. In element %s", selectors.c_str(), GetAddress().c_str());
		return;
	}

	QuerySelectorAllMatchRecursive(elements, leaf_nodes, this);
}

EventDispatcher* Element::GetEventDispatcher() const {
	return &meta->event_dispatcher;
}

DataModel* Element::GetDataModel() const {
	return data_model;
}

void Element::OnAttributeChange(const ElementAttributes& changed_attributes)
{
	auto it = changed_attributes.find("id");
	if (it != changed_attributes.end())
	{
		id = it->second;
		meta->style.DirtyDefinition();
	}

	it = changed_attributes.find("class");
	if (it != changed_attributes.end())
	{
		meta->style.SetClassNames(it->second);
	}

	it = changed_attributes.find("style");
	if (it != changed_attributes.end())
	{
		PropertyDictionary properties;
		StyleSheetParser parser;
		parser.ParseProperties(properties, it->second);

		for (const auto& name_value : properties.GetProperties())
		{
			meta->style.SetProperty(name_value.first, name_value.second);
		}
	}
	
	for (const auto& pair: changed_attributes)
	{
		if (pair.first.size() > 2 && pair.first[0] == 'o' && pair.first[1] == 'n')
		{
			EventListener* listener = Factory::InstanceEventListener(pair.second, this);
			if (listener)
				AddEventListener(pair.first.substr(2), listener, false);
		}
	}
}

void Element::OnChange(const PropertyIdSet& changed_properties) {
	const bool border_radius_changed = (
		changed_properties.Contains(PropertyId::BorderTopLeftRadius) ||
		changed_properties.Contains(PropertyId::BorderTopRightRadius) ||
		changed_properties.Contains(PropertyId::BorderBottomRightRadius) ||
		changed_properties.Contains(PropertyId::BorderBottomLeftRadius)
		);

	if (changed_properties.Contains(PropertyId::Display)) {
		// Due to structural pseudo-classes, this may change the element definition in siblings and parent.
		// However, the definitions will only be changed on the next update loop which may result in jarring behavior for one @frame.
		// A possible workaround is to add the parent to a list of elements that need to be updated again.
		if (parent != nullptr)
			parent->DirtyStructure();
	}

	if (changed_properties.Contains(PropertyId::ZIndex)) {
		float new_z_index = 0;
		const Property* property = GetProperty(PropertyId::ZIndex);
		if (property->unit != Property::KEYWORD) {
			new_z_index = property->Get<float>();
		}
		if (z_index != new_z_index) {
			z_index = new_z_index;
			if (parent != nullptr) {
				parent->DirtyStackingContext();
			}
		}
	}

	if (border_radius_changed ||
		changed_properties.Contains(PropertyId::BackgroundColor) ||
		changed_properties.Contains(PropertyId::BackgroundImage) ||
		changed_properties.Contains(PropertyId::Opacity))
	{
		dirty_background = true;
	}

	if (border_radius_changed ||
		changed_properties.Contains(PropertyId::BorderTopWidth) ||
		changed_properties.Contains(PropertyId::BorderRightWidth) ||
		changed_properties.Contains(PropertyId::BorderBottomWidth) ||
		changed_properties.Contains(PropertyId::BorderLeftWidth) ||
		changed_properties.Contains(PropertyId::BorderTopColor) ||
		changed_properties.Contains(PropertyId::BorderRightColor) ||
		changed_properties.Contains(PropertyId::BorderBottomColor) ||
		changed_properties.Contains(PropertyId::BorderLeftColor) ||
		changed_properties.Contains(PropertyId::Opacity))
	{
		dirty_border = true;
	}

	if (border_radius_changed ||
		changed_properties.Contains(PropertyId::BackgroundImage) ||
		changed_properties.Contains(PropertyId::BackgroundOrigin) ||
		changed_properties.Contains(PropertyId::BackgroundSize) ||
		changed_properties.Contains(PropertyId::BackgroundSizeX) ||
		changed_properties.Contains(PropertyId::BackgroundSizeY) ||
		changed_properties.Contains(PropertyId::BackgroundPositionX) ||
		changed_properties.Contains(PropertyId::BackgroundPositionY) ||
		changed_properties.Contains(PropertyId::BackgroundRepeat) ||
		changed_properties.Contains(PropertyId::Opacity))
	{
		dirty_image = true;
	}

	if (changed_properties.Contains(PropertyId::Perspective) ||
		changed_properties.Contains(PropertyId::PerspectiveOriginX) ||
		changed_properties.Contains(PropertyId::PerspectiveOriginY))
	{
		DirtyPerspective();
	}

	if (changed_properties.Contains(PropertyId::Transform) ||
		changed_properties.Contains(PropertyId::TransformOriginX) ||
		changed_properties.Contains(PropertyId::TransformOriginY) ||
		changed_properties.Contains(PropertyId::TransformOriginZ))
	{
		DirtyTransform();
	}

	if (changed_properties.Contains(PropertyId::Animation))
	{
		dirty_animation = true;
	}

	if (changed_properties.Contains(PropertyId::Transition))
	{
		dirty_transition = true;
	}

	for (auto& child : children) {
		if (child->GetType() == Node::Type::Text) {
			child->OnChange(changed_properties);
		}
	}
}

void Element::ProcessDefaultAction(Event& event)
{
	if (event.GetId() == EventId::Mousedown && event.GetParameter<int>("button", 0) == (int)MouseButton::Left) {
		SetPseudoClass("active", true);
	}

	if (event.GetPhase() == EventPhase::Target)
	{
		switch (event.GetId())
		{
		case EventId::Mouseover:
			SetPseudoClass("hover", true);
			break;
		case EventId::Mouseout:
			SetPseudoClass("hover", false);
			break;
		default:
			break;
		}
	}
}

const Style::ComputedValues& Element::GetComputedValues() const
{
	return meta->computed_values;
}

std::string Element::GetInnerRML() const {
	std::string rml;
	for (auto& child : children) {
		if (child->GetType() == Node::Type::Text) {
			rml += ((ElementText&)*child).GetText();
		}
		else {
			rml += child->GetOuterRML();
		}
	}
	return rml;
}

std::string Element::GetOuterRML() const {
	std::string rml;
	rml += "<";
	rml += tag;
	for (auto& pair : attributes) {
		auto& name = pair.first;
		auto& value = pair.second;
		rml += " " + name + "=\"" + value + "\"";
	}
	if (!children.empty()) {
		rml += ">";
		rml += GetInnerRML();
		rml += "</";
		rml += tag;
		rml += ">";
	}
	else {
		rml += " />";
	}
	return rml;
}

void Element::SetDataModel(DataModel* new_data_model)  {
	RMLUI_ASSERTMSG(!data_model || !new_data_model, "We must either attach a new data model, or detach the old one.");

	if (data_model == new_data_model)
		return;

	if (data_model)
		data_model->OnElementRemove(this);

	data_model = new_data_model;

	if (data_model)
		ElementUtilities::ApplyDataViewsControllers(this);

	for (ElementPtr& child : children)
		child->SetDataModel(new_data_model);
}

void Element::SetParent(Element* _parent) {
	RMLUI_ASSERT(!parent || !_parent);
	if (parent) {
		RMLUI_ASSERT(GetOwnerDocument() == parent->GetOwnerDocument());
	}

	parent = _parent;
	Node::SetParentNode(parent);

	if (parent) {
		// We need to update our definition and make sure we inherit the properties of our new parent.
		meta->style.DirtyDefinition();
		meta->style.DirtyInheritedProperties();
	}

	// The transform state may require recalculation.
	DirtyTransform();
	DirtyPerspective();

	if (!parent)
	{
		if (data_model)
			SetDataModel(nullptr);
	}
	else 
	{
		auto it = attributes.find("data-model");
		if (it == attributes.end())
		{
			SetDataModel(parent->data_model);
		}
		else if (parent->data_model)
		{
			std::string const& name = it->second;
			Log::Message(Log::Level::Error, "Nested data models are not allowed. Data model '%s' given in element %s.", name.c_str(), GetAddress().c_str());
		}
		else if (Document* document = GetOwnerDocument())
		{
			std::string const& name = it->second;
			if (DataModel* model = document->GetDataModelPtr(name))
			{
				model->AttachModelRootElement(this);
				SetDataModel(model);
			}
			else
				Log::Message(Log::Level::Error, "Could not locate data model '%s' in element %s.", name.c_str(), GetAddress().c_str());
		}
	}
}

void Element::UpdateStackingContext() {
	if (!stacking_context_dirty) {
		return;
	}
	stacking_context_dirty = false;
	stacking_context.clear();
	stacking_context.reserve(children.size());
	for (auto& child : children) {
		stacking_context.push_back(child.get());
	}
	std::stable_sort(stacking_context.begin(), stacking_context.end(),
		[](const Element* lhs, const Element* rhs) {
			return lhs->GetZIndex() < rhs->GetZIndex();
		}
	);
}

void Element::DirtyStackingContext() {
	stacking_context_dirty = true;
}

void Element::DirtyStructure() {
	structure_dirty = true;
}

void Element::UpdateStructure() {
	if (structure_dirty) {
		structure_dirty = false;
		GetStyle()->DirtyDefinition();
	}
}

void Element::StartAnimation(PropertyId property_id, const Property* start_value, int num_iterations, bool alternate_direction, float delay, bool initiated_by_animation_property) {
	Property value;
	if (start_value) {
		value = *start_value;
		if (!value.definition)
			if (auto default_value = GetProperty(property_id))
				value.definition = default_value->definition;	
	}
	else if (auto default_value = GetProperty(property_id)) {
		value = *default_value;
	}
	if (!value.definition) {
		return;
	}
	ElementAnimationOrigin origin = (initiated_by_animation_property ? ElementAnimationOrigin::Animation : ElementAnimationOrigin::User);
	double start_time = GetContext()->GetElapsedTime() + (double)delay;

	ElementAnimation animation{ property_id, origin, value, *this, start_time, 0.0f, num_iterations, alternate_direction };
	auto it = std::find_if(animations.begin(), animations.end(), [&](const ElementAnimation& el) { return el.GetPropertyId() == property_id; });
	if (it == animations.end()) {
		if (animation.IsInitalized()) {
			animations.emplace_back(std::move(animation));
		}
	}
	else {
		if (animation.IsInitalized()) {
			*it = std::move(animation);
		}
		else {
			animations.erase(it);
		}
	}
}

bool Element::AddAnimationKeyTime(PropertyId property_id, const Property* target_value, float time, Tween tween)
{
	if (!target_value)
		target_value = meta->style.GetProperty(property_id);
	if (!target_value)
		return false;
	ElementAnimation* animation = nullptr;
	for (auto& existing_animation : animations) {
		if (existing_animation.GetPropertyId() == property_id) {
			animation = &existing_animation;
			break;
		}
	}
	if (!animation)
		return false;
	return animation->AddKey(time, *target_value, *this, tween, false);
}

bool Element::StartTransition(const Transition& transition, const Property& start_value, const Property & target_value, bool remove_when_complete)
{
	auto it = std::find_if(animations.begin(), animations.end(), [&](const ElementAnimation& el) { return el.GetPropertyId() == transition.id; });

	if (it != animations.end() && !it->IsTransition())
		return false;

	float duration = transition.duration;
	double start_time = GetContext()->GetElapsedTime() + (double)transition.delay;

	if (it == animations.end()) {
		// Add transition as new animation
		animations.emplace_back(
			transition.id, ElementAnimationOrigin::Transition, start_value, *this, start_time, 0.0f, 1, false 
		);
		it = (animations.end() - 1);
	}
	else {
		// Compress the duration based on the progress of the current animation
		float f = it->GetInterpolationFactor();
		f = 1.0f - (1.0f - f)*transition.reverse_adjustment_factor;
		duration = duration * f;
		// Replace old transition
		*it = ElementAnimation{ transition.id, ElementAnimationOrigin::Transition, start_value, *this, start_time, 0.0f, 1, false };
	}

	if (!it->AddKey(duration, target_value, *this, transition.tween, remove_when_complete)) {
		animations.erase(it);
		return false;
	}
	SetPropertyImmediate(transition.id, start_value);
	return true;
}

void Element::HandleTransitionProperty() {
	if (!dirty_transition) {
		return;
	}
	dirty_transition = false;

	// Remove all transitions that are no longer in our local list
	const TransitionList& keep_transitions = GetComputedValues().transition;

	if (keep_transitions.all)
		return;

	auto it_remove = animations.end();

	if (keep_transitions.none) {
		// All transitions should be removed, but only touch the animations that originate from the 'transition' property.
		// Move all animations to be erased in a valid state at the end of the list, and erase later.
		it_remove = std::partition(animations.begin(), animations.end(),
			[](const ElementAnimation& animation) -> bool { return !animation.IsTransition(); }
		);
	}
	else {
		// Only remove the transitions that are not in our keep list.
		const auto& keep_transitions_list = keep_transitions.transitions;

		it_remove = std::partition(animations.begin(), animations.end(),
			[&keep_transitions_list](const ElementAnimation& animation) -> bool {
				if (!animation.IsTransition())
					return true;
				auto it = std::find_if(keep_transitions_list.begin(), keep_transitions_list.end(),
					[&animation](const Transition& transition) { return animation.GetPropertyId() == transition.id; }
				);
				bool keep_animation = (it != keep_transitions_list.end());
				return keep_animation;
			}
		);
	}

	// We can decide what to do with cancelled transitions here.
	for (auto it = it_remove; it != animations.end(); ++it)
		it->Release(*this);

	animations.erase(it_remove, animations.end());
}

void Element::HandleAnimationProperty()
{
	// Note: We are effectively restarting all animations whenever 'dirty_animation' is set. Use the dirty flag with care,
	// or find another approach which only updates actual "dirty" animations.
	if (!dirty_animation) {
		return;
	}
	dirty_animation = false;

	const AnimationList& animation_list = meta->computed_values.animation;
	bool element_has_animations = (!animation_list.empty() || !animations.empty());
	StyleSheet* stylesheet = nullptr;

	if (element_has_animations)
		stylesheet = GetStyleSheet().get();

	if (stylesheet)
	{
		// Remove existing animations
		{
			// We only touch the animations that originate from the 'animation' property.
			auto it_remove = std::partition(animations.begin(), animations.end(), 
				[](const ElementAnimation & animation) { return animation.GetOrigin() != ElementAnimationOrigin::Animation; }
			);

			// We can decide what to do with cancelled animations here.
			for (auto it = it_remove; it != animations.end(); ++it)
				it->Release(*this);

			animations.erase(it_remove, animations.end());
		}

		// Start animations
		for (const auto& animation : animation_list)
		{
			const Keyframes* keyframes_ptr = stylesheet->GetKeyframes(animation.name);
			if (keyframes_ptr && keyframes_ptr->blocks.size() >= 1 && !animation.paused)
			{
				auto& property_ids = keyframes_ptr->property_ids;
				auto& blocks = keyframes_ptr->blocks;

				bool has_from_key = (blocks[0].normalized_time == 0);
				bool has_to_key = (blocks.back().normalized_time == 1);

				// If the first key defines initial conditions for a given property, use those values, else, use this element's current values.
				for (PropertyId id : property_ids)
					StartAnimation(id, (has_from_key ? blocks[0].properties.GetProperty(id) : nullptr), animation.num_iterations, animation.alternate, animation.delay, true);

				// Add middle keys: Need to skip the first and last keys if they set the initial and end conditions, respectively.
				for (int i = (has_from_key ? 1 : 0); i < (int)blocks.size() + (has_to_key ? -1 : 0); i++)
				{
					// Add properties of current key to animation
					float time = blocks[i].normalized_time * animation.duration;
					for (auto& property : blocks[i].properties.GetProperties())
						AddAnimationKeyTime(property.first, &property.second, time, animation.tween);
				}

				// If the last key defines end conditions for a given property, use those values, else, use this element's current values.
				float time = animation.duration;
				for (PropertyId id : property_ids)
					AddAnimationKeyTime(id, (has_to_key ? blocks.back().properties.GetProperty(id) : nullptr), time, animation.tween);
			}
		}
	}
}

void Element::AdvanceAnimations()
{
	if (animations.empty()) {
		return;
	}
	double time = GetContext()->GetElapsedTime();

	for (auto& animation : animations)
	{
		Property property = animation.UpdateAndGetProperty(time, *this);
		if (property.unit != Property::UNKNOWN)
			SetPropertyImmediate(animation.GetPropertyId(), property);
	}

	// Move all completed animations to the end of the list
	auto it_completed = std::partition(animations.begin(), animations.end(), [](const ElementAnimation& animation) { return !animation.IsComplete(); });

	std::vector<Dictionary> dictionary_list;
	std::vector<bool> is_transition;
	dictionary_list.reserve(animations.end() - it_completed);
	is_transition.reserve(animations.end() - it_completed);

	for (auto it = it_completed; it != animations.end(); ++it)
	{
		const std::string& property_name = StyleSheetSpecification::GetPropertyName(it->GetPropertyId());

		dictionary_list.emplace_back();
		dictionary_list.back().emplace("property", Variant(property_name));
		is_transition.push_back(it->IsTransition());

		it->Release(*this);
	}

	// Need to erase elements before submitting event, as iterators might be invalidated when calling external code.
	animations.erase(it_completed, animations.end());

	for (size_t i = 0; i < dictionary_list.size(); i++)
		DispatchEvent(is_transition[i] ? EventId::Transitionend : EventId::Animationend, dictionary_list[i]);
}

void Element::DirtyPerspective()
{
	dirty_perspective = true;
}

void Element::UpdateTransform() {
	if (!dirty_transform)
		return;
	dirty_transform = false;
	glm::mat4x4 new_transform(1);
	glm::vec3 origin(metrics.frame.origin.x, metrics.frame.origin.y, 0);
	auto computedTransform = GetProperty(PropertyId::Transform)->Get<TransformPtr>();
	if (computedTransform && !computedTransform->empty()) {
		glm::vec3 transform_origin = origin + glm::vec3 {
			ComputePropertyW(GetProperty(PropertyId::TransformOriginX), this),
			ComputePropertyH(GetProperty(PropertyId::TransformOriginY), this),
			ComputeProperty (GetProperty(PropertyId::TransformOriginZ), this),
		};
		new_transform = glm::translate(transform_origin) * computedTransform->GetMatrix(*this) * glm::translate(-transform_origin);
	}
	new_transform = glm::translate(new_transform, origin);
	if (parent) {
		if (parent->perspective) {
			new_transform = *parent->perspective * new_transform;
		}
		new_transform = parent->transform * new_transform;
	}

	if (new_transform != transform) {
		transform = new_transform;
		for (auto& child : children) {
			child->DirtyTransform();
		}
		have_inv_transform = true;
		inv_transform.reset();
	}
}

void Element::UpdatePerspective() {
	if (!dirty_perspective)
		return;
	dirty_perspective = false;
	float distance = ComputeProperty(GetProperty(PropertyId::Perspective), this);
	bool changed = false;
	if (distance > 0.0f) {
		glm::vec3 origin {
			ComputePropertyW(GetProperty(PropertyId::PerspectiveOriginX), this),
			ComputePropertyH(GetProperty(PropertyId::PerspectiveOriginY), this),
			0.f,
		};
		// Equivalent to: translate(origin) * perspective(distance) * translate(-origin)
		glm::mat4x4 new_perspective = {
			{ 1, 0, 0, 0 },
			{ 0, 1, 0, 0 },
			{ -origin.x / distance, -origin.y / distance, 1, -1 / distance },
			{ 0, 0, 0, 1 }
		};
		
		if (!perspective || new_perspective != *perspective) {
			perspective = std::make_unique<glm::mat4x4>(new_perspective);
			changed = true;
		}
	}
	else {
		if (!perspective) {
			perspective.reset();
			changed = true;
		}
	}

	if (changed) {
		for (auto& child : children) {
			child->DirtyTransform();
		}
	}
}

void Element::UpdateGeometry() {
	if (dirty_background || dirty_border) {
		if (!geometry_border) {
			geometry_border.reset(new Geometry);
		}
		ElementBackgroundBorder::GenerateGeometry(this, *geometry_border, padding_edge);
		dirty_background = false;
		dirty_border = false;
		dirty_image = true;
	}
	if (dirty_image) {
		if (!geometry_image) {
			geometry_image.reset(new Geometry);
		}
		ElementBackgroundImage::GenerateGeometry(this, *geometry_image, padding_edge);
		dirty_image = false;
	}
}

void Element::UpdateLayout() {
	if (Node::UpdateMetrics() && Node::IsVisible()) {
		DirtyTransform();
		dirty_background = true;
		dirty_image = true;
		dirty_border = true;
		for (auto& child : children) {
			child->UpdateLayout();
		}
	}
}

Element* Element::GetElementAtPoint(Point point, const Element* ignore_element) {
	UpdateStackingContext();
	for (int i = (int)stacking_context.size() - 1; i >= 0; --i) {
		if (ignore_element != nullptr) {
			Element* element_hierarchy = stacking_context[i];
			while (element_hierarchy != nullptr) {
				if (element_hierarchy == ignore_element)
					break;
				element_hierarchy = element_hierarchy->GetParentNode();
			}
			if (element_hierarchy != nullptr)
				continue;
		}
		Element* child_element = stacking_context[i]->GetElementAtPoint(point, ignore_element);
		if (child_element != nullptr) {
			return child_element;
		}
	}

	if (IsPointWithinElement(point)) {
		return this;
	}
	return nullptr;
}

void Element::UpdateClip() {
	if (!dirty_clip)
		return;
	dirty_clip = false;

	if (GetLayout().GetOverflow() == Layout::Overflow::Visible) {
		clip_type = Clip::None;
		return;
	}
	Size size = GetMetrics().frame.size;
	if (size.IsEmpty()) {
		clip_type = Clip::None;
		return;
	}
	Rect scissorRect{ {}, size };
	glm::vec4 corners[] = {
		{scissorRect.left(),  scissorRect.top(),    0, 1},
		{scissorRect.right(), scissorRect.top(),    0, 1},
		{scissorRect.right(), scissorRect.bottom(), 0, 1},
		{scissorRect.left(),  scissorRect.bottom(), 0, 1},
	};
	for (auto& c : corners) {
		c = transform * c;
		c /= c.w;
	}
	if (corners[0].x == corners[3].x
		&& corners[0].y == corners[1].y
		&& corners[2].x == corners[1].x
		&& corners[2].y == corners[3].y
	) {
		clip_type = Clip::Scissor;
		clip.scissor.x = (glm::u16)std::floor(corners[0].x);
		clip.scissor.y = (glm::u16)std::floor(corners[0].y);
		clip.scissor.z = (glm::u16)std::ceil(corners[2].x - clip.scissor.x);
		clip.scissor.w = (glm::u16)std::ceil(corners[2].y - clip.scissor.y);
		return;
	}
	clip_type = Clip::Shader;
	clip.shader[0].x = corners[0].x; clip.shader[0].y = corners[0].y;
	clip.shader[0].z = corners[1].x; clip.shader[0].w = corners[1].y;
	clip.shader[1].z = corners[2].x; clip.shader[1].w = corners[2].y;
	clip.shader[1].x = corners[3].x; clip.shader[1].y = corners[3].y;
}

void Element::SetRednerStatus() {
	auto render = GetRenderInterface();
	render->SetTransform(transform);
	switch (clip_type) {
	case Clip::None:    render->SetClipRect();             break;
	case Clip::Scissor: render->SetClipRect(clip.scissor); break;
	case Clip::Shader:  render->SetClipRect(clip.shader);  break;
	}
}

void Element::DirtyTransform() {
	dirty_transform = true;
	dirty_clip = true;
}

void Element::SetAttribute(const std::string& name, const std::string& value) {
	attributes[name] = value;
    ElementAttributes changed_attributes;
    changed_attributes.emplace(name, value);
	OnAttributeChange(changed_attributes);
}

std::string Element::GetAttribute(const std::string& name, const std::string& default_value) const {
	const std::string* r = GetAttribute(name);
	if (!r) {
		return default_value;
	}
	return *r;
}

} // namespace Rml
