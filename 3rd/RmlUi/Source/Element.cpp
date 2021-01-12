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
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/ElementDocument.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/Dictionary.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/TransformPrimitive.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "Clock.h"
#include "ComputeProperty.h"
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
#include "TransformState.h"
#include "TransformUtilities.h"
#include "XMLParseTools.h"
#include <algorithm>
#include <cmath>

namespace Rml {

// Meta objects for element collected in a single struct to reduce memory allocations
struct ElementMeta
{
	ElementMeta(Element* el) : event_dispatcher(el), style(el), background_border(el), background_image(el) {}
	EventDispatcher event_dispatcher;
	ElementStyle style;
	ElementBackgroundBorder background_border;
	ElementBackgroundImage background_image;
	Style::ComputedValues computed_values;
};


static Pool< ElementMeta > element_meta_chunk_pool(200, true);


/// Constructs a new RmlUi element.
Element::Element(const String& tag) 
	: tag(tag)
	, scroll_offset(0, 0)
	, content_offset(0, 0)
	, content_box(0, 0)
	, transform_state()
	, dirty_transform(false)
	, dirty_perspective(false)
	, dirty_animation(false)
	, dirty_transition(false)
{
	RMLUI_ASSERT(tag == StringUtilities::ToLower(tag));
	parent = nullptr;
	focus = nullptr;
	owner_document = nullptr;
	z_index = 0;
	stacking_context_dirty = true;
	structure_dirty = false;
	computed_values_are_default_initialized = true;
	meta = element_meta_chunk_pool.AllocateAndConstruct(this);
	data_model = nullptr;
	PluginRegistry::NotifyElementCreate(this);
}

Element::~Element()
{
	RMLUI_ASSERT(parent == nullptr);	

	PluginRegistry::NotifyElementDestroy(this);

	// A simplified version of RemoveChild() for destruction.
	for (ElementPtr& child : children)
	{
		child->SetParent(nullptr);
	}

	children.clear();

	element_meta_chunk_pool.DestroyAndDeallocate(meta);
}

void Element::Update(float dp_ratio)
{
	UpdateStructure();
	HandleTransitionProperty();
	HandleAnimationProperty();
	AdvanceAnimations();
	UpdateProperties();

	// Do en extra pass over the animations and properties if the 'animation' property was just changed.
	if (dirty_animation)
	{
		HandleAnimationProperty();
		AdvanceAnimations();
		UpdateProperties();
	}

	for (size_t i = 0; i < children.size(); i++)
		children[i]->Update(dp_ratio);
}


void Element::UpdateProperties() {
	meta->style.UpdateDefinition();

	if (meta->style.AnyPropertiesDirty()) {
		const ComputedValues* parent_values = nullptr;
		if (parent)
			parent_values = &parent->GetComputedValues();

		const ComputedValues* document_values = nullptr;
		float dp_ratio = 1.0f;
		if (auto doc = GetOwnerDocument()) {
			document_values = &doc->GetComputedValues();
			if (Context * context = doc->GetContext())
				dp_ratio = context->GetDensityIndependentPixelRatio();
		}

		// Compute values and clear dirty properties
		PropertyIdSet dirty_properties = meta->style.ComputeValues(meta->computed_values, parent_values, document_values, computed_values_are_default_initialized, dp_ratio);

		computed_values_are_default_initialized = false;

		// Computed values are just calculated and can safely be used in OnPropertyChange.
		// However, new properties set during this call will not be available until the next update loop.
		if (!dirty_properties.Empty())
			OnPropertyChange(dirty_properties);
	}
}

void Element::Render()
{
	UpdateStackingContext();
	UpdateTransformState();

	// Render all elements in our local stacking context that have a z-index beneath our local index of 0.
	size_t i = 0;
	for (; i < stacking_context.size() && stacking_context[i]->z_index < 0; ++i)
		stacking_context[i]->Render();

	// Apply our transform
	if (transform_state && transform_state->GetTransform()) {
		GetRenderInterface()->SetTransform(transform_state->GetTransform());
	}
	else {
		GetRenderInterface()->SetTransform(&Matrix4f::Identity());
	}

	// Set up the clipping region for this element.
	GetRenderInterface()->SetScissorRegion(GetClippingRegion());
	meta->background_border.Render(this);
	meta->background_image.Render();
	OnRender();

	// Render the rest of the elements in the stacking context.
	for (; i < stacking_context.size(); ++i)
		stacking_context[i]->Render();
}

// Clones this element, returning a new, unparented element.
ElementPtr Element::Clone() const
{
	ElementPtr clone(new Element(GetTagName()));
	clone->SetOwnerDocument(GetOwnerDocument());
	clone->SetAttributes(attributes);
	String inner_rml;
	GetInnerRML(inner_rml);
	clone->SetInnerRML(inner_rml);
	return clone;
}

// Sets or removes a class on the element.
void Element::SetClass(const String& class_name, bool activate)
{
	meta->style.SetClass(class_name, activate);
}

// Checks if a class is set on the element.
bool Element::IsClassSet(const String& class_name) const
{
	return meta->style.IsClassSet(class_name);
}

// Specifies the entire list of classes for this element. This will replace any others specified.
void Element::SetClassNames(const String& class_names)
{
	SetAttribute("class", class_names);
}

/// Return the active class list
String Element::GetClassNames() const
{
	return meta->style.GetClassNames();
}

// Returns the active style sheet for this element. This may be nullptr.
const SharedPtr<StyleSheet>& Element::GetStyleSheet() const
{
	if (ElementDocument * document = GetOwnerDocument())
		return document->GetStyleSheet();
	static SharedPtr<StyleSheet> null_style_sheet;
	return null_style_sheet;
}

// Returns the element's definition.
const ElementDefinition* Element::GetDefinition()
{
	return meta->style.GetDefinition();
}

// Fills an String with the full address of this element.
String Element::GetAddress(bool include_pseudo_classes, bool include_parents) const
{
	// Add the tag name onto the address.
	String address(tag);

	// Add the ID if we have one.
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

Layout& Element::GetLayout() {
	return layout;
}

const Layout::Metrics& Element::GetMetrics() const {
	return metrics;
}

Point& Element::GetOffset() {
	if (dirty_offset) {
		dirty_offset = false;
		if (parent) {
			offset = metrics.frame.origin + parent->GetOffset();
		}
		else {
			offset = metrics.frame.origin;
		}
	}
	return offset;
}

void Element::DirtyOffset() {
	if (dirty_offset) {
		return;
	}
	dirty_offset = true;
	if (transform_state) {
		DirtyTransformState(true, true);
	}
	for (auto& child : children) {
		child->DirtyOffset();
	}
}

bool Element::IsPointWithinElement(const Point& point) {
	return Rect(GetOffset(), metrics.frame.size).Contains(point);
}

bool Element::IsVisible() const {
	return metrics.visible;
}

void Element::SetVisible(bool visible) {
	if (IsVisible() == visible) {
		return;
	}
	layout.SetVisible(visible);
	layout.MarkDirty();
}

// Returns the z-index of the element.
float Element::GetZIndex() const
{
	return z_index;
}

// Returns the element's font face handle.
FontFaceHandle Element::GetFontFaceHandle() const
{
	return meta->computed_values.font_face_handle;
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

// Removes a local property override on the element.
void Element::RemoveProperty(const String& name)
{
	meta->style.RemoveProperty(StyleSheetSpecification::GetPropertyId(name));
}

// Removes a local property override on the element.
void Element::RemoveProperty(PropertyId id)
{
	meta->style.RemoveProperty(id);
}

// Returns one of this element's properties.
const Property* Element::GetProperty(const String& name)
{
	return meta->style.GetProperty(StyleSheetSpecification::GetPropertyId(name));
}

// Returns one of this element's properties.
const Property* Element::GetProperty(PropertyId id)
{
	return meta->style.GetProperty(id);
}

// Returns one of this element's properties.
const Property* Element::GetLocalProperty(const String& name)
{
	return meta->style.GetLocalProperty(StyleSheetSpecification::GetPropertyId(name));
}

const Property* Element::GetLocalProperty(PropertyId id)
{
	return meta->style.GetLocalProperty(id);
}

const PropertyMap& Element::GetLocalStyleProperties()
{
	return meta->style.GetLocalStyleProperties();
}

float Element::ResolveNumericProperty(const Property *property, float base_value)
{
	return meta->style.ResolveNumericProperty(property, base_value);
}

// Project a 2D point in pixel coordinates onto the element's plane.
bool Element::Project(Point& point) const noexcept
{
	if(!transform_state || !transform_state->GetTransform())
		return true;

	// The input point is in window coordinates. Need to find the projection of the point onto the current element plane,
	// taking into account the full transform applied to the element.

	if (const Matrix4f* inv_transform = transform_state->GetInverseTransform())
	{
		// Pick two points forming a line segment perpendicular to the window.
		Vector4f window_points[2] = {{ point.x, point.y, -10, 1}, { point.x, point.y, 10, 1 }};

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
		if(std::fabs(ray.z) > 1.0f)
		{
			// Solving the line equation p = p0 + t*ray for t, knowing that p.z = 0, produces the following.
			float t = -local_points[0].z / ray.z;
			Vector3f p = local_points[0] + ray * t;

			point = Point(p.x, p.y);
			return true;
		}
	}

	// The transformation matrix is either singular, or the ray is parallel to the element's plane.
	return false;
}

// Sets or removes a pseudo-class on the element.
void Element::SetPseudoClass(const String& pseudo_class, bool activate)
{
	meta->style.SetPseudoClass(pseudo_class, activate);
}

// Checks if a specific pseudo-class has been set on the element.
bool Element::IsPseudoClassSet(const String& pseudo_class) const
{
	return meta->style.IsPseudoClassSet(pseudo_class);
}

// Checks if a complete set of pseudo-classes are set on the element.
bool Element::ArePseudoClassesSet(const PseudoClassList& pseudo_classes) const
{
	for (PseudoClassList::const_iterator i = pseudo_classes.begin(); i != pseudo_classes.end(); ++i)
	{
		if (!IsPseudoClassSet(*i))
			return false;
	}

	return true;
}

// Gets a list of the current active pseudo classes
const PseudoClassList& Element::GetActivePseudoClasses() const
{
	return meta->style.GetActivePseudoClasses();
}

/// Get the named attribute
Variant* Element::GetAttribute(const String& name)
{
	return GetIf(attributes, name);
}

// Checks if the element has a certain attribute.
bool Element::HasAttribute(const String& name) const
{
	return attributes.find(name) != attributes.end();
}

// Removes an attribute from the element
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

// Gets the outer most focus element down the tree from this node
Element* Element::GetFocusLeafNode()
{
	// If there isn't a focus, then we are the leaf.
	if (!focus)
	{
		return this;
	}

	// Recurse down the tree until we found the leaf focus element
	Element* focus_element = focus;
	while (focus_element->focus)
		focus_element = focus_element->focus;

	return focus_element;
}

// Returns the element's context.
Context* Element::GetContext() const
{
	ElementDocument* document = GetOwnerDocument();
	if (document != nullptr)
		return document->GetContext();

	return nullptr;
}

// Set a group of attributes
void Element::SetAttributes(const ElementAttributes& _attributes)
{
	attributes.reserve(attributes.size() + _attributes.size());
	for (auto& pair : _attributes)
		attributes[pair.first] = pair.second;

	OnAttributeChange(_attributes);
}

// Returns the number of attributes on the element.
int Element::GetNumAttributes() const
{
	return (int)attributes.size();
}

// Gets the name of the element.
const String& Element::GetTagName() const
{
	return tag;
}

// Gets the ID of the element.
const String& Element::GetId() const
{
	return id;
}

// Sets the ID of the element.
void Element::SetId(const String& _id)
{
	SetAttribute("id", _id);
}

// Gets the left scroll offset of the element.
float Element::GetScrollLeft()
{
	return scroll_offset.x;
}

// Sets the left scroll offset of the element.
void Element::SetScrollLeft(float scroll_left)
{
	const float new_offset = Math::Clamp(Math::RoundFloat(scroll_left), 0.0f, GetScrollWidth() - metrics.frame.size.w);
	if (new_offset != scroll_offset.x)
	{
		scroll_offset.x = new_offset;

		DispatchEvent(EventId::Scroll, Dictionary());
	}
}

// Gets the top scroll offset of the element.
float Element::GetScrollTop()
{
	return scroll_offset.y;
}

// Sets the top scroll offset of the element.
void Element::SetScrollTop(float scroll_top)
{
	const float new_offset = Math::Clamp(Math::RoundFloat(scroll_top), 0.0f, GetScrollHeight() - metrics.frame.size.h);
	if(new_offset != scroll_offset.y)
	{
		scroll_offset.y = new_offset;

		DispatchEvent(EventId::Scroll, Dictionary());
	}
}

// Gets the width of the scrollable content of the element; it includes the element padding but not its margin.
float Element::GetScrollWidth()
{
	return Math::Max(content_box.x, metrics.frame.size.w);
}

// Gets the height of the scrollable content of the element; it includes the element padding but not its margin.
float Element::GetScrollHeight()
{
	return Math::Max(content_box.y, metrics.frame.size.h);
}

// Gets the object representing the declarations of an element's style attributes.
ElementStyle* Element::GetStyle() const
{
	return &meta->style;
}

// Gets the document this element belongs to.
ElementDocument* Element::GetOwnerDocument() const
{
#ifdef RMLUI_DEBUG
	if (parent && !owner_document)
	{
		// Since we have a parent but no owner_document, then we must be a 'loose' element -- that is, constructed
		// outside of a document and not attached to a child of any element in the hierarchy of a document.
		// This check ensures that we didn't just forget to set the owner document.
		RMLUI_ASSERT(!parent->GetOwnerDocument());
	}
#endif

	return owner_document;
}

// Gets this element's parent node.
Element* Element::GetParentNode() const
{
	return parent;
}

// Gets the element immediately following this one in the tree.
Element* Element::GetNextSibling() const
{
	if (parent == nullptr)
		return nullptr;

	for (size_t i = 0; i < parent->children.size() - 1; i++)
	{
		if (parent->children[i].get() == this)
			return parent->children[i + 1].get();
	}

	return nullptr;
}

// Gets the element immediately preceding this one in the tree.
Element* Element::GetPreviousSibling() const
{
	if (parent == nullptr)
		return nullptr;

	for (size_t i = 1; i < parent->children.size(); i++)
	{
		if (parent->children[i].get() == this)
			return parent->children[i - 1].get();
	}

	return nullptr;
}

// Returns the first child of this element.
Element* Element::GetFirstChild() const
{
	if (GetNumChildren() > 0)
		return children[0].get();

	return nullptr;
}

// Gets the last child of this element.
Element* Element::GetLastChild() const
{
	if (GetNumChildren() > 0)
		return (children.end() - 1)->get();

	return nullptr;
}

Element* Element::GetChild(int index) const
{
	if (index < 0 || index >= (int) children.size())
		return nullptr;

	return children[index].get();
}

int Element::GetNumChildren() const
{
	return (int)children.size();
}

// Gets the markup and content of the element.
void Element::GetInnerRML(String& content) const {
	for (auto& child : children) {
		child->GetRML(content);
	}
}

// Gets the markup and content of the element.
String Element::GetInnerRML() const {
	String result;
	GetInnerRML(result);
	return result;
}

// Sets the markup and content of the element. All existing children will be replaced.
void Element::SetInnerRML(const String& rml)
{
	// Remove all DOM children.
	while ((int) children.size() > 0)
		RemoveChild(children.front().get());

	if(!rml.empty())
		Factory::InstanceElementText(this, rml);
}

// Sets the current element as the focus object.
bool Element::Focus()
{
	// Are we allowed focus?
	Style::Focus focus_property = meta->computed_values.focus;
	if (focus_property == Style::Focus::None)
		return false;

	ElementDocument* document = GetOwnerDocument();
	if (!document || !document->ChangeFocus(this)) {
		return false;
	}

	focus = nullptr;
	Element* element = this;
	while (Element* parent = element->GetParentNode()) {
		parent->focus = element;
		element = parent;
	}
	return true;
}

// Removes focus from from this element.
void Element::Blur() {
	if (parent) {
		ElementDocument* document = GetOwnerDocument();
		if (!document)
			return;
		if (document->GetFocus() == this) {
			parent->Focus();
		}
		else if (parent->focus == this) {
			parent->focus = nullptr;
		}
	}
}

// Adds an event listener
void Element::AddEventListener(const String& event, EventListener* listener, bool in_capture_phase)
{
	EventId id = EventSpecificationInterface::GetIdOrInsert(event);
	meta->event_dispatcher.AttachEvent(id, listener, in_capture_phase);
}

// Adds an event listener
void Element::AddEventListener(EventId id, EventListener* listener, bool in_capture_phase)
{
	meta->event_dispatcher.AttachEvent(id, listener, in_capture_phase);
}

// Removes an event listener from this element.
void Element::RemoveEventListener(const String& event, EventListener* listener, bool in_capture_phase)
{
	EventId id = EventSpecificationInterface::GetIdOrInsert(event);
	meta->event_dispatcher.DetachEvent(id, listener, in_capture_phase);
}

// Removes an event listener from this element.
void Element::RemoveEventListener(EventId id, EventListener* listener, bool in_capture_phase)
{
	meta->event_dispatcher.DetachEvent(id, listener, in_capture_phase);
}

// Dispatches the specified event
bool Element::DispatchEvent(const String& type, const Dictionary& parameters)
{
	const EventSpecification& specification = EventSpecificationInterface::GetOrInsert(type);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, specification.interruptible, specification.bubbles, specification.default_action_phase);
}

// Dispatches the specified event
bool Element::DispatchEvent(const String& type, const Dictionary& parameters, bool interruptible, bool bubbles)
{
	const EventSpecification& specification = EventSpecificationInterface::GetOrInsert(type);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, interruptible, bubbles, specification.default_action_phase);
}

// Dispatches the specified event
bool Element::DispatchEvent(EventId id, const Dictionary& parameters)
{
	const EventSpecification& specification = EventSpecificationInterface::Get(id);
	return EventDispatcher::DispatchEvent(this, specification.id, parameters, specification.interruptible, specification.bubbles, specification.default_action_phase);
}


// Appends a child to this element
Element* Element::AppendChild(ElementPtr child)
{
	RMLUI_ASSERT(child);
	Element* child_ptr = child.get();
	layout.InsertChild(child->GetLayout(), (uint32_t)children.size());
	children.insert(children.end(), std::move(child));
	// Set parent just after inserting into children. This allows us to eg. get our previous sibling in SetParent.
	child_ptr->SetParent(this);
	DirtyStackingContext();
	DirtyStructure();
	DirtyLayout();
	return child_ptr;
}

// Adds a child to this element, directly after the adjacent element. Inherits
// the dom/non-dom status from the adjacent element.
Element* Element::InsertBefore(ElementPtr child, Element* adjacent_element)
{
	RMLUI_ASSERT(child);
	// Find the position in the list of children of the adjacent element. If
	// it's nullptr or we can't find it, then we insert it at the end of the dom
	// children, as a dom element.
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

		layout.InsertChild(child->GetLayout(), (uint32_t)child_index);
		DirtyLayout();

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

// Replaces the second node with the first node.
ElementPtr Element::ReplaceChild(ElementPtr inserted_element, Element* replaced_element)
{
	RMLUI_ASSERT(inserted_element);
	auto insertion_point = children.begin();
	while (insertion_point != children.end() && insertion_point->get() != replaced_element)
	{
		++insertion_point;
	}

	Element* inserted_element_ptr = inserted_element.get();

	if (insertion_point == children.end())
	{
		AppendChild(std::move(inserted_element));
		return nullptr;
	}

	children.insert(insertion_point, std::move(inserted_element));
	inserted_element_ptr->SetParent(this);
	return RemoveChild(replaced_element);
}

// Removes the specified child
ElementPtr Element::RemoveChild(Element* child)
{
	size_t child_index = 0;

	for (auto itr = children.begin(); itr != children.end(); ++itr)
	{
		// Add the element to the delete list
		if (itr->get() == child)
		{
			Element* ancestor = child;

			ElementPtr detached_child = std::move(*itr);
			children.erase(itr);

			// Remove the child element as the focused child of this element.
			if (child == focus) {
				focus = nullptr;
				// If this child (or a descendant of this child) is the context's currently
				// focused element, set the focus to us instead.
				if (ElementDocument* document = GetOwnerDocument()) {
					Element* focus_element = document->GetFocus();
					while (focus_element) {
						if (focus_element == child) {
							Focus();
							break;
						}
						focus_element = focus_element->GetParentNode();
					}
				}
			}

			detached_child->SetParent(nullptr);

			layout.RemoveChild(child->GetLayout());
			DirtyLayout();
			DirtyStackingContext();
			DirtyStructure();

			return detached_child;
		}

		child_index++;
	}

	return nullptr;
}


bool Element::HasChildNodes() const
{
	return (int) children.size() > 0;
}

Element* Element::GetElementById(const String& id)
{
	// Check for special-case tokens.
	if (id == "#self")
		return this;
	else if (id == "#document")
		return GetOwnerDocument();
	else if (id == "#parent")
		return this->parent;
	Element* search_root = GetOwnerDocument();
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
		
		// Add all children to search
		for (int i = 0; i < element->GetNumChildren(); i++)
			search_queue.push(element->GetChild(i));
	}
	return nullptr;
}

// Get all elements with the given tag.
void Element::GetElementsByTagName(ElementList& elements, const String& tag)
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

		if (element->GetTagName() == tag)
			elements.push_back(element);

		// Add all children to search.
		for (int i = 0; i < element->GetNumChildren(); i++)
			search_queue.push(element->GetChild(i));
	}
}

// Get all elements with the given class set on them.
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

		// Add all children to search.
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

// Access the event dispatcher
EventDispatcher* Element::GetEventDispatcher() const
{
	return &meta->event_dispatcher;
}

String Element::GetEventDispatcherSummary() const
{
	return meta->event_dispatcher.ToString();
}

DataModel* Element::GetDataModel() const
{
	return data_model;
}

bool Element::IsClippingEnabled() {
	return layout.GetOverflow() != Layout::Overflow::Visible;
}

// Called during render after backgrounds, borders, but before children, are rendered.
void Element::OnRender()
{
}

// Called when attributes on the element are changed.
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
void Element::OnPropertyChange(const PropertyIdSet& changed_properties) {
	const PropertyIdSet changed_properties_forcing_layout = (changed_properties & StyleSheetSpecification::GetRegisteredPropertiesForcingLayout());
	if (!changed_properties_forcing_layout.Empty()) {
		DirtyLayout();
	}

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
		Style::ZIndex z_index_property = meta->computed_values.z_index;
		float new_z_index = z_index_property.type == Style::ZIndex::Auto
			? 0
			: z_index_property.value;
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
		meta->background_border.DirtyBackground();
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
		meta->background_border.DirtyBorder();
	}
	
	// Dirty the decoration if it's changed.
	if (border_radius_changed ||
		changed_properties.Contains(PropertyId::BackgroundImage) ||
		changed_properties.Contains(PropertyId::Opacity))
	{
		meta->background_image.MarkDirty();
	}

	// Check for `perspective' and `perspective-origin' changes
	if (changed_properties.Contains(PropertyId::Perspective) ||
		changed_properties.Contains(PropertyId::PerspectiveOriginX) ||
		changed_properties.Contains(PropertyId::PerspectiveOriginY))
	{
		DirtyTransformState(true, false);
	}

	// Check for `transform' and `transform-origin' changes
	if (changed_properties.Contains(PropertyId::Transform) ||
		changed_properties.Contains(PropertyId::TransformOriginX) ||
		changed_properties.Contains(PropertyId::TransformOriginY) ||
		changed_properties.Contains(PropertyId::TransformOriginZ))
	{
		DirtyTransformState(false, true);
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
}

void Element::DirtyLayout() {
	layout.MarkDirty();
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
		case EventId::Focus:
			SetPseudoClass("focus", true);
			break;
		case EventId::Blur:
			SetPseudoClass("focus", false);
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

void Element::GetRML(String& content)
{
	// First we start the open tag, add the attributes then close the open tag.
	// Then comes the children in order, then we add our close tag.
	content += "<";
	content += tag;

	for (auto& pair : attributes)
	{
		auto& name = pair.first;
		auto& variant = pair.second;
		String value;
		if (variant.GetInto(value))
			content += " " + name + "=\"" + value + "\"";
	}

	if (HasChildNodes())
	{
		content += ">";

		GetInnerRML(content);

		content += "</";
		content += tag;
		content += ">";
	}
	else
	{
		content += " />";
	}
}

void Element::SetOwnerDocument(ElementDocument* document)
{
	if (owner_document && !document) {
		// We are detaching from the document and thereby also the context.
		owner_document->OnElementDetach(this);
	}

	// If this element is a document, then never change owner_document.
	if (owner_document != this && owner_document != document)
	{
		owner_document = document;
		for (ElementPtr& child : children)
			child->SetOwnerDocument(document);
	}
}

void Element::SetDataModel(DataModel* new_data_model) 
{
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

void Element::SetParent(Element* _parent)
{
	// Assumes we are already detached from the hierarchy or we are detaching now.
	RMLUI_ASSERT(!parent || !_parent);

	parent = _parent;

	if (parent)
	{
		// We need to update our definition and make sure we inherit the properties of our new parent.
		meta->style.DirtyDefinition();
		meta->style.DirtyInheritedProperties();
	}

	// The transform state may require recalculation.
	if (transform_state || (parent && parent->transform_state))
		DirtyTransformState(true, true);

	SetOwnerDocument(parent ? parent->GetOwnerDocument() : nullptr);

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
		else if (ElementDocument* document = GetOwnerDocument())
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
		// If this element or its children depend on structured selectors, they may need to be updated.
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

void Element::DirtyTransformState(bool perspective_dirty, bool transform_dirty)
{
	dirty_perspective |= perspective_dirty;
	dirty_transform |= transform_dirty;
}

void Element::UpdateTransformState()
{
	if (!dirty_perspective && !dirty_transform)
		return;

	const ComputedValues& computed = meta->computed_values;

	const Point pos = GetOffset();
	const Size size = metrics.frame.size;
	
	bool perspective_or_transform_changed = false;

	if (dirty_perspective)
	{
		// If perspective is set on this element, then it applies to our children. We just calculate it here, 
		// and let the children's transform update merge it with their transform.
		bool had_perspective = (transform_state && transform_state->GetLocalPerspective());

		float distance = computed.perspective;
		Point vanish(pos.x + size.w * 0.5f, pos.y + size.h * 0.5f);
		bool have_perspective = false;

		if (distance > 0.0f)
		{
			have_perspective = true;

			// Compute the vanishing point from the perspective origin
			if (computed.perspective_origin_x.type == Style::PerspectiveOrigin::Percentage)
				vanish.x = pos.x + computed.perspective_origin_x.value * 0.01f * size.w;
			else
				vanish.x = pos.x + computed.perspective_origin_x.value;

			if (computed.perspective_origin_y.type == Style::PerspectiveOrigin::Percentage)
				vanish.y = pos.y + computed.perspective_origin_y.value * 0.01f * size.h;
			else
				vanish.y = pos.y + computed.perspective_origin_y.value;
		}

		if (have_perspective)
		{
			// Equivalent to: Translate(x,y,0) * Perspective(distance) * Translate(-x,-y,0)
			Matrix4f perspective = Matrix4f::FromRows(
				{ 1, 0, -vanish.x / distance, 0 },
				{ 0, 1, -vanish.y / distance, 0 },
				{ 0, 0, 1, 0 },
				{ 0, 0, -1 / distance, 1 }
			);

			if (!transform_state)
				transform_state = MakeUnique<TransformState>();

			perspective_or_transform_changed |= transform_state->SetLocalPerspective(&perspective);
		}
		else if (transform_state)
			transform_state->SetLocalPerspective(nullptr);

		perspective_or_transform_changed |= (have_perspective != had_perspective);

		dirty_perspective = false;
	}


	if (dirty_transform)
	{
		// We want to find the accumulated transform given all our ancestors. It is assumed here that the parent transform is already updated,
		// so that we only need to consider our local transform and combine it with our parent's transform and perspective matrices.
		bool had_transform = (transform_state && transform_state->GetTransform());

		bool have_transform = false;
		Matrix4f transform = Matrix4f::Identity();

		if (computed.transform)
		{
			// First find the current element's transform
			const int n = computed.transform->GetNumPrimitives();
			for (int i = 0; i < n; ++i)
			{
				const TransformPrimitive& primitive = computed.transform->GetPrimitive(i);
				Matrix4f matrix = TransformUtilities::ResolveTransform(primitive, *this);
				transform *= matrix;
				have_transform = true;
			}

			if(have_transform)
			{
				// Compute the transform origin
				Vector3f transform_origin(pos.x + size.w * 0.5f, pos.y + size.h * 0.5f, 0);

				if (computed.transform_origin_x.type == Style::TransformOrigin::Percentage)
					transform_origin.x = pos.x + computed.transform_origin_x.value * size.w * 0.01f;
				else
					transform_origin.x = pos.x + computed.transform_origin_x.value;

				if (computed.transform_origin_y.type == Style::TransformOrigin::Percentage)
					transform_origin.y = pos.y + computed.transform_origin_y.value * size.h * 0.01f;
				else
					transform_origin.y = pos.y + computed.transform_origin_y.value;

				transform_origin.z = computed.transform_origin_z;

				// Make the transformation apply relative to the transform origin
				transform = Matrix4f::Translate(transform_origin) * transform * Matrix4f::Translate(-transform_origin);
			}

			// We may want to include the local offsets here, as suggested by the CSS specs, so that the local transform is applied after the offset I believe
			// the motivation is. Then we would need to subtract the absolute zero-offsets during geometry submit whenever we have transforms.
		}

		if (parent && parent->transform_state)
		{
			// Apply the parent's local perspective and transform.
			// @performance: If we have no local transform and no parent perspective, we can effectively just point to the parent transform instead of copying it.
			const TransformState& parent_state = *parent->transform_state;

			if (auto parent_perspective = parent_state.GetLocalPerspective())
			{
				transform = *parent_perspective * transform;
				have_transform = true;
			}

			if (auto parent_transform = parent_state.GetTransform())
			{
				transform = *parent_transform * transform;
				have_transform = true;
			}
		}

		if (have_transform)
		{
			if (!transform_state)
				transform_state = MakeUnique<TransformState>();

			perspective_or_transform_changed |= transform_state->SetTransform(&transform);
		}
		else if (transform_state)
			transform_state->SetTransform(nullptr);

		perspective_or_transform_changed |= (had_transform != have_transform);
	}

	// A change in perspective or transform will require an update to children transforms as well.
	if (perspective_or_transform_changed)
	{
		for (size_t i = 0; i < children.size(); i++)
			children[i]->DirtyTransformState(false, true);
	}

	// No reason to keep the transform state around if transform and perspective have been removed.
	if (transform_state && !transform_state->GetTransform() && !transform_state->GetLocalPerspective())
	{
		transform_state.reset();
	}
}

void Element::UpdateBounds() {
	if (!layout.UpdateMetrics(metrics)) {
		return;
	}
	if (IsVisible()) {
		DirtyOffset();
		for (auto& child : children) {
			child->UpdateBounds();
		}
	}
	else {
		Blur();
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

	// Ignore elements whose pointer events are disabled.
	if (GetComputedValues().pointer_events == Style::PointerEvents::None)
		return nullptr;

	// Projection may fail if we have a singular transformation matrix.
	bool projection_result = Project(point);

	// Check if the point is actually within this element.
	bool within_element = (projection_result && IsPointWithinElement(point));
	if (within_element) {
		Rect clip = GetClippingRegion();
		if (!clip.IsEmpty()) {
			within_element = clip.Contains(point);
		}
	}
	if (within_element) {
		return this;
	}
	return nullptr;
}

Rect Element::GetClippingRegion() {
	Rect clip;
	if (parent) {
		clip = parent->GetClippingRegion();
	}
	if (!IsClippingEnabled()) {
		return clip;
	}
	clip.Union(Rect(GetOffset(), metrics.frame.size));
	return clip;
}

} // namespace Rml
