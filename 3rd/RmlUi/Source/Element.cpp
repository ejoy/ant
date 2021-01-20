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
#include "../Include/RmlUi/TransformPrimitive.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/StreamMemory.h"
#include "Clock.h"
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
#include "Pool.h"
#include "StyleSheetParser.h"
#include "StyleSheetNode.h"
#include "TransformUtilities.h"
#include "XMLParseTools.h"
#include <algorithm>
#include <cmath>
#include <yoga/YGNode.h>

namespace Rml {

struct ElementMeta {
	ElementMeta(Element* el) : event_dispatcher(el), style(el) {}
	EventDispatcher event_dispatcher;
	ElementStyle style;
	Style::ComputedValues computed_values;
};

Element::Element(Document* owner, const String& tag)
	: owner_document(owner)
	, tag(tag)
	, dirty_perspective(false)
	, dirty_animation(false)
	, dirty_transition(false)
{
	RMLUI_ASSERT(tag == StringUtilities::ToLower(tag));
	GetLayout().SetContext(this);
	parent = nullptr;
	z_index = 0;
	stacking_context_dirty = true;
	structure_dirty = false;
	meta = new ElementMeta(this);
	data_model = nullptr;
	PluginRegistry::NotifyElementCreate(this);
}

Element::~Element() {
	RMLUI_ASSERT(parent == nullptr);
	//GetOwnerDocument()->OnElementDetach(this);
	SetDataModel(nullptr);
	PluginRegistry::NotifyElementDestroy(this);
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
	UpdateTransform();
	UpdatePerspective();
	UpdateGeometry();

	size_t i = 0;
	for (; i < stacking_context.size() && stacking_context[i]->GetZIndex() < 0; ++i) {
		stacking_context[i]->OnRender();
	}
	SetClipRegion();
	GetRenderInterface()->SetTransform(&transform);
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

void Element::SetClass(const String& class_name, bool activate)
{
	meta->style.SetClass(class_name, activate);
}

bool Element::IsClassSet(const String& class_name) const
{
	return meta->style.IsClassSet(class_name);
}

void Element::SetClassNames(const String& class_names)
{
	SetAttribute("class", class_names);
}

String Element::GetClassNames() const
{
	return meta->style.GetClassNames();
}

const SharedPtr<StyleSheet>& Element::GetStyleSheet() const
{
	if (Document * document = GetOwnerDocument())
		return document->GetStyleSheet();
	static SharedPtr<StyleSheet> null_style_sheet;
	return null_style_sheet;
}

const ElementDefinition* Element::GetDefinition()
{
	return meta->style.GetDefinition();
}

String Element::GetAddress(bool include_pseudo_classes, bool include_parents) const
{
	String address(tag);

	if (!id.empty())
	{
		address += "#";
		address += id;
	}

	String classes = meta->style.GetClassNames();
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

bool Element::IsPointWithinElement(const Point& point) {
	return GetMetrics().frame.Contains(point);
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
			return fontSize * 0.01 * property->Get<float>();
		}
		return fontSize * property->Get<float>();
	}
	if (property->unit == Property::REM) {
		if (element == element->GetOwnerDocument()->body.get()) {
			return property->Get<float>() * 16;
		}
	}
	return ComputeProperty<float>(property, element);
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

bool Element::SetProperty(const String& name, const String& value) {
	PropertyDictionary properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, value)) {
		Log::Message(Log::LT_WARNING, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value.c_str());
		return false;
	}
	for (auto& property : properties.GetProperties()) {
		if (!meta->style.SetProperty(property.first, property.second))
			return false;
	}
	return true;
}

bool Element::SetPropertyImmediate(const String& name, const String& value) {
	PropertyDictionary properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, value)) {
		Log::Message(Log::LT_WARNING, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value.c_str());
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

void Element::RemoveProperty(const String& name)
{
	meta->style.RemoveProperty(StyleSheetSpecification::GetPropertyId(name));
}

void Element::RemoveProperty(PropertyId id)
{
	meta->style.RemoveProperty(id);
}

const Property* Element::GetProperty(const String& name)
{
	return meta->style.GetProperty(StyleSheetSpecification::GetPropertyId(name));
}

const Property* Element::GetProperty(PropertyId id)
{
	return meta->style.GetProperty(id);
}

float Element::ResolveNumericProperty(const Property *property, float base_value)
{
	return meta->style.ResolveNumericProperty(property, base_value);
}

// Project a 2D point in pixel coordinates onto the element's plane.
bool Element::Project(Point& point) const noexcept
{
	// The input point is in window coordinates. Need to find the projection of the point onto the current element plane,
	// taking into account the full transform applied to the element.
	if (!inv_transform) {
		inv_transform = MakeUnique<Matrix4f>(transform);
		have_inv_transform = inv_transform->Invert();
	}
	if (!have_inv_transform) {
		return false;
	}

	// Pick two points forming a line segment perpendicular to the window.
	Vector4f window_points[2] = { { point.x, point.y, -10, 1}, { point.x, point.y, 10, 1 } };

	// Project them into the local element space.
	window_points[0] = *inv_transform * window_points[0];
	window_points[1] = *inv_transform * window_points[1];

	Vector3f local_points[2] = {
		window_points[0].PerspectiveDivide(),
		window_points[1].PerspectiveDivide()
	};

	// Construct a ray from the two projected points in the local space of the current element.
	// Find the intersection with the z=0 plane to produce our destination point.
	Vector3f ray = local_points[1] - local_points[0];

	// Only continue if we are not close to parallel with the plane.
	if (std::fabs(ray.z) > 1.0f)
	{
		// Solving the line equation p = p0 + t*ray for t, knowing that p.z = 0, produces the following.
		float t = -local_points[0].z / ray.z;
		Vector3f p = local_points[0] + ray * t;

		point = Point(p.x, p.y);
		return true;
	}

	// The transformation matrix is either singular, or the ray is parallel to the element's plane.
	return false;
}

void Element::SetPseudoClass(const String& pseudo_class, bool activate)
{
	meta->style.SetPseudoClass(pseudo_class, activate);
}

bool Element::IsPseudoClassSet(const String& pseudo_class) const
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

Variant* Element::GetAttribute(const String& name)
{
	return GetIf(attributes, name);
}

bool Element::HasAttribute(const String& name) const
{
	return attributes.find(name) != attributes.end();
}

void Element::RemoveAttribute(const String& name)
{
	auto it = attributes.find(name);
	if (it != attributes.end())
	{
		attributes.erase(it);

		ElementAttributes changed_attributes;
		changed_attributes.emplace(name, Variant());
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

const String& Element::GetTagName() const
{
	return tag;
}

const String& Element::GetId() const
{
	return id;
}

void Element::SetId(const String& _id)
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

void Element::SetInnerRML(const String& rml) {
	while ((int) children.size() > 0)
		RemoveChild(children.front().get());
	if (rml.empty()) {
		return;
	}

	if (std::all_of(rml.begin(), rml.end(), &StringUtilities::IsWhitespace))
		return;
	auto stream = MakeUnique<StreamMemory>(rml.size() + 32);
	Context* context = parent->GetContext();
	String open_tag = "<" + tag + ">";
	String close_tag = "</" + tag + ">";
	stream->Write(open_tag.c_str(), open_tag.size());
	stream->Write(rml);
	stream->Write(close_tag.c_str(), close_tag.size());
	stream->Seek(0, SEEK_SET);
	XMLParser parser(parent);
	parser.Parse(stream.get());
}

void Element::AddEventListener(const String& event, EventListener* listener, bool in_capture_phase) {
	EventId id = EventSpecificationInterface::GetIdOrInsert(event);
	meta->event_dispatcher.AttachEvent(id, listener, in_capture_phase);
}

void Element::AddEventListener(EventId id, EventListener* listener, bool in_capture_phase) {
	meta->event_dispatcher.AttachEvent(id, listener, in_capture_phase);
}

void Element::RemoveEventListener(const String& event, EventListener* listener, bool in_capture_phase) {
	EventId id = EventSpecificationInterface::GetIdOrInsert(event);
	meta->event_dispatcher.DetachEvent(id, listener, in_capture_phase);
}

void Element::RemoveEventListener(EventId id, EventListener* listener, bool in_capture_phase)
{
	meta->event_dispatcher.DetachEvent(id, listener, in_capture_phase);
}

bool Element::DispatchEvent(const String& type, const Dictionary& parameters) {
	const EventSpecification& specification = EventSpecificationInterface::GetOrInsert(type);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, specification.interruptible, specification.bubbles, specification.default_action_phase);
}

bool Element::DispatchEvent(const String& type, const Dictionary& parameters, bool interruptible, bool bubbles) {
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

Element* Element::GetElementById(const String& id) {
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
	typedef Queue<Element*> SearchQueue;
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

void Element::GetElementsByTagName(ElementList& elements, const String& tag) {
	// Breadth first search on elements for the corresponding id
	typedef Queue< Element* > SearchQueue;
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

void Element::GetElementsByClassName(ElementList& elements, const String& class_name)
{
	// Breadth first search on elements for the corresponding id
	typedef Queue< Element* > SearchQueue;
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

Element* Element::QuerySelector(const String& selectors)
{
	StyleSheetNode root_node;
	StyleSheetNodeListRaw leaf_nodes = StyleSheetParser::ConstructNodes(root_node, selectors);

	if (leaf_nodes.empty())
	{
		Log::Message(Log::LT_WARNING, "Query selector '%s' is empty. In element %s", selectors.c_str(), GetAddress().c_str());
		return nullptr;
	}

	return QuerySelectorMatchRecursive(leaf_nodes, this);
}

void Element::QuerySelectorAll(ElementList& elements, const String& selectors)
{
	StyleSheetNode root_node;
	StyleSheetNodeListRaw leaf_nodes = StyleSheetParser::ConstructNodes(root_node, selectors);

	if (leaf_nodes.empty())
	{
		Log::Message(Log::LT_WARNING, "Query selector '%s' is empty. In element %s", selectors.c_str(), GetAddress().c_str());
		return;
	}

	QuerySelectorAllMatchRecursive(elements, leaf_nodes, this);
}

EventDispatcher* Element::GetEventDispatcher() const {
	return &meta->event_dispatcher;
}

String Element::GetEventDispatcherSummary() const {
	return meta->event_dispatcher.ToString();
}

DataModel* Element::GetDataModel() const {
	return data_model;
}

bool Element::IsClippingEnabled() {
	return GetLayout().GetOverflow() != Layout::Overflow::Visible;
}

void Element::OnAttributeChange(const ElementAttributes& changed_attributes)
{
	auto it = changed_attributes.find("id");
	if (it != changed_attributes.end())
	{
		id = it->second.Get<String>();
		meta->style.DirtyDefinition();
	}

	it = changed_attributes.find("class");
	if (it != changed_attributes.end())
	{
		meta->style.SetClassNames(it->second.Get<String>());
	}

	it = changed_attributes.find("style");
	if (it != changed_attributes.end())
	{
		if (it->second.GetType() == Variant::STRING)
		{
			PropertyDictionary properties;
			StyleSheetParser parser;
			parser.ParseProperties(properties, it->second.GetReference<String>());

			for (const auto& name_value : properties.GetProperties())
			{
				meta->style.SetProperty(name_value.first, name_value.second);
			}
		}
		else if (it->second.GetType() != Variant::NONE)
		{
			Log::Message(Log::LT_WARNING, "Invalid 'style' attribute, string type required. In element: %s", GetAddress().c_str());
		}
	}
	
	for (const auto& pair: changed_attributes)
	{
		if (pair.first.size() > 2 && pair.first[0] == 'o' && pair.first[1] == 'n')
		{
			EventListener* listener = Factory::InstanceEventListener(pair.second.Get<String>(), this);
			if (listener)
				AddEventListener(pair.first.substr(2), listener, false);
		}
	}
}

// Called when properties on the element are changed.
void Element::OnChange(const PropertyIdSet& changed_properties) {
	const bool border_radius_changed = (
		changed_properties.Contains(PropertyId::BorderTopLeftRadius) ||
		changed_properties.Contains(PropertyId::BorderTopRightRadius) ||
		changed_properties.Contains(PropertyId::BorderBottomRightRadius) ||
		changed_properties.Contains(PropertyId::BorderBottomLeftRadius)
	);

	// Update the visibility.
	if (changed_properties.Contains(PropertyId::Display)) {
		// Due to structural pseudo-classes, this may change the element definition in siblings and parent.
		// However, the definitions will only be changed on the next update loop which may result in jarring behavior for one @frame.
		// A possible workaround is to add the parent to a list of elements that need to be updated again.
		if (parent != nullptr)
			parent->DirtyStructure();
	}

	// Update the z-index.
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

	// Dirty the background if it's changed.
    if (border_radius_changed ||
		changed_properties.Contains(PropertyId::BackgroundColor) ||
		changed_properties.Contains(PropertyId::BackgroundImage) ||
		changed_properties.Contains(PropertyId::Opacity))
	{
		dirty_background = true;
    }

	// Dirty the border if it's changed.
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
	
	// Dirty the decoration if it's changed.
	if (border_radius_changed ||
		changed_properties.Contains(PropertyId::BackgroundImage) ||
		changed_properties.Contains(PropertyId::Opacity))
	{
		dirty_image = true;
	}

	// Check for `perspective' and `perspective-origin' changes
	if (changed_properties.Contains(PropertyId::Perspective) ||
		changed_properties.Contains(PropertyId::PerspectiveOriginX) ||
		changed_properties.Contains(PropertyId::PerspectiveOriginY))
	{
		DirtyPerspective();
	}

	// Check for `transform' and `transform-origin' changes
	if (changed_properties.Contains(PropertyId::Transform) ||
		changed_properties.Contains(PropertyId::TransformOriginX) ||
		changed_properties.Contains(PropertyId::TransformOriginY) ||
		changed_properties.Contains(PropertyId::TransformOriginZ))
	{
		DirtyTransform();
	}

	// Check for `animation' changes
	if (changed_properties.Contains(PropertyId::Animation))
	{
		dirty_animation = true;
	}
	// Check for `transition' changes
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
	if (event.GetId() == EventId::Mousedown && event.GetParameter<int>("button", 0) == 0) {
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

String Element::GetInnerRML() const {
	String rml;
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

String Element::GetOuterRML() const {
	String rml;
	rml += "<";
	rml += tag;
	for (auto& pair : attributes) {
		auto& name = pair.first;
		auto& variant = pair.second;
		String value;
		if (variant.GetInto(value))
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
			String name = it->second.Get<String>();
			Log::Message(Log::LT_ERROR, "Nested data models are not allowed. Data model '%s' given in element %s.", name.c_str(), GetAddress().c_str());
		}
		else if (Document* document = GetOwnerDocument())
		{
			String name = it->second.Get<String>();
			if (DataModel* model = document->GetDataModelPtr(name))
			{
				model->AttachModelRootElement(this);
				SetDataModel(model);
			}
			else
				Log::Message(Log::LT_ERROR, "Could not locate data model '%s' in element %s.", name.c_str(), GetAddress().c_str());
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

bool Element::AddAnimationKey(const String & property_name, const Property & target_value, float duration, Tween tween)
{
	ElementAnimation* animation = nullptr;
	PropertyId property_id = StyleSheetSpecification::GetPropertyId(property_name);
	for (auto& existing_animation : animations) {
		if (existing_animation.GetPropertyId() == property_id) {
			animation = &existing_animation;
			break;
		}
	}
	if (!animation)
		return false;
	return animation->AddKey(animation->GetDuration() + duration, target_value, *this, tween, true);
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
	double start_time = Clock::GetElapsedTime() + (double)delay;

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
	return animation->AddKey(time, *target_value, *this, tween, true);
}

bool Element::StartTransition(const Transition& transition, const Property& start_value, const Property & target_value, bool remove_when_complete)
{
	auto it = std::find_if(animations.begin(), animations.end(), [&](const ElementAnimation& el) { return el.GetPropertyId() == transition.id; });

	if (it != animations.end() && !it->IsTransition())
		return false;

	float duration = transition.duration;
	double start_time = Clock::GetElapsedTime() + (double)transition.delay;

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

	if (!it->AddKey(duration, target_value, *this, transition.tween, true)) {
		animations.erase(it);
		return false;
	}
	it->SetRemoveWhenComplete(remove_when_complete);
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
	double time = Clock::GetElapsedTime();

	for (auto& animation : animations)
	{
		Property property = animation.UpdateAndGetProperty(time, *this);
		if (property.unit != Property::UNKNOWN)
			SetPropertyImmediate(animation.GetPropertyId(), property);
	}

	// Move all completed animations to the end of the list
	auto it_completed = std::partition(animations.begin(), animations.end(), [](const ElementAnimation& animation) { return !animation.IsComplete(); });

	Vector<Dictionary> dictionary_list;
	Vector<bool> is_transition;
	dictionary_list.reserve(animations.end() - it_completed);
	is_transition.reserve(animations.end() - it_completed);

	for (auto it = it_completed; it != animations.end(); ++it)
	{
		const String& property_name = StyleSheetSpecification::GetPropertyName(it->GetPropertyId());

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
	const ComputedValues& computed = meta->computed_values;
	Matrix4f new_transform = Matrix4f::Identity();
	if (computed.transform && !computed.transform->Empty()) {
		const Layout::Metrics& metrics = GetMetrics();
		Vector3f origin {
			computed.transform_origin_x.value,
			computed.transform_origin_y.value,
			computed.transform_origin_z,
		};
		if (computed.transform_origin_x.type == Style::TransformOrigin::Percentage) {
			origin.x *= metrics.frame.size.w * 0.01f;
		}
		if (computed.transform_origin_y.type == Style::TransformOrigin::Percentage) {
			origin.y *= metrics.frame.size.h * 0.01f;
		}
		new_transform = Matrix4f::Translate(origin)
			* computed.transform->GetMatrix(*this)
			* Matrix4f::Translate(-origin);
	}
	new_transform = Matrix4f::Translate(metrics.frame.origin.x, metrics.frame.origin.y, 0) * new_transform;
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
	const ComputedValues& computed = meta->computed_values;
	float distance = computed.perspective;
	bool changed = false;
	if (distance > 0.0f) {
		const Layout::Metrics& metrics = GetMetrics();
		Point origin {
			computed.perspective_origin_x.value,
			computed.perspective_origin_y.value,
		};
		if (computed.perspective_origin_x.type == Style::PerspectiveOrigin::Percentage) {
			origin.x *= metrics.frame.size.w * 0.01f;
		}
		if (computed.perspective_origin_y.type == Style::PerspectiveOrigin::Percentage) {
			origin.y *= metrics.frame.size.h * 0.01f;
		}
		// Equivalent to: Translate(x,y,0) * Perspective(distance) * Translate(-x,-y,0)
		Matrix4f new_perspective = Matrix4f::FromRows(
			{ 1, 0, -origin.x / distance, 0 },
			{ 0, 1, -origin.y / distance, 0 },
			{ 0, 0, 1, 0 },
			{ 0, 0, -1 / distance, 1 }
		);
		if (!perspective || new_perspective != *perspective) {
			perspective = MakeUnique<Matrix4f>(new_perspective);
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

	if (Project(point) && IsPointWithinElement(point)) {
		return this;
	}
	return nullptr;
}

void Element::SetClipRegion() {
}

} // namespace Rml
