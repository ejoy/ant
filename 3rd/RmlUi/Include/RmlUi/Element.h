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

#ifndef RMLUI_CORE_ELEMENT_H
#define RMLUI_CORE_ELEMENT_H

#include "Header.h"
#include "Layout.h"
#include "ComputedValues.h"
#include "Event.h"
#include "ObserverPtr.h"
#include "Property.h"
#include "Types.h"
#include "Transform.h"
#include "Tween.h"
#include "Geometry.h"
#include "Node.h"

namespace Rml {

class Context;
class DataModel;
class EventDispatcher;
class EventListener;
class ElementDefinition;
class Document;
class ElementStyle;
class PropertyDictionary;
class StyleSheet;
class Geometry;
struct ElementMeta;
struct StackingOrderedChild;

/**
	A generic element in the DOM tree.

	@author Peter Curry
 */

class RMLUICORE_API Element : public Node, public EnableObserverPtr<Element>
{
public:
	Element(Document* owner, const String& tag);
	virtual ~Element();

	/** @name Classes
	 */
	//@{
	/// Sets or removes a class on the element.
	/// @param[in] class_name The name of the class to add or remove from the class list.
	/// @param[in] activate True if the class is to be added, false to be removed.
	void SetClass(const String& class_name, bool activate);
	/// Checks if a class is set on the element.
	/// @param[in] class_name The name of the class to check for.
	/// @return True if the class is set on the element, false otherwise.
	bool IsClassSet(const String& class_name) const;
	/// Specifies the entire list of classes for this element. This will replace any others specified.
	/// @param[in] class_names The list of class names to set on the style, separated by spaces.
	void SetClassNames(const String& class_names);
	/// Return the active class list.
	/// @return The space-separated list of classes active on the element.
	String GetClassNames() const;
	//@}

	/// Returns the active style sheet for this element. This may be nullptr.
	/// @return The element's style sheet.
	virtual const SharedPtr<StyleSheet>& GetStyleSheet() const;

	/// Returns the element's definition.
	/// @return The element's definition.
	const ElementDefinition* GetDefinition();

	/// Fills a string with the full address of this element.
	/// @param[in] include_pseudo_classes True if the address is to include the pseudo-classes of the leaf element.
	/// @return The address of the element, including its full parentage.
	String GetAddress(bool include_pseudo_classes = false, bool include_parents = true) const;

	/// Checks if a given point in screen coordinates lies within the bordered area of this element.
	/// @param[in] point The point to test.
	/// @return True if the element is within this element, false otherwise.
	bool IsPointWithinElement(const Point& point);

	float GetZIndex() const;
	float GetFontSize() const;
	float GetOpacity();

	bool UpdataFontSize();

	/** @name Properties
	 */
	//@{
	/// Sets a local property override on the element.
	/// @param[in] name The name of the new property.
	/// @param[in] value The new property to set.
	/// @return True if the property parsed successfully, false otherwise.
	bool SetProperty(const String& name, const String& value);
	bool SetPropertyImmediate(const String& name, const String& value);
	/// Sets a local property override on the element to a pre-parsed value.
	/// @param[in] name The name of the new property.
	/// @param[in] property The parsed property to set.
	/// @return True if the property was set successfully, false otherwise.
	bool SetProperty(PropertyId id, const Property& property);
	bool SetPropertyImmediate(PropertyId id, const Property& property);
	/// Removes a local property override on the element; its value will revert to that defined in the style sheet.
	/// @param[in] name The name of the local property definition to remove.
	void RemoveProperty(const String& name);
	void RemoveProperty(PropertyId id);
	/// Returns one of this element's properties. If the property is not defined for this element and not inherited 
	/// from an ancestor, the default value will be returned.
	/// @param[in] name The name of the property to fetch the value for.
	/// @return The value of this property for this element, or nullptr if no property exists with the given name.
	const Property* GetProperty(const String& name);		
	const Property* GetProperty(PropertyId id);		
	/// Returns the values of one of this element's properties.		
	/// @param[in] name The name of the property to get.
	/// @return The value of this property.
	template < typename T >
	T GetProperty(const String& name);

	/// Resolves a property with units of number, percentage, length, or angle to their canonical unit (unit-less, 'px', or 'rad').
	/// Numbers and percentages are scaled by the base value and returned.
	/// @param[in] property The property to resolve the value for.
	/// @param[in] base_value The value that is scaled by the number or percentage value, if applicable.
	/// @return The resolved value in their canonical unit, or zero if it could not be resolved.
	float ResolveNumericProperty(const Property *property, float base_value);

	/// Project a 2D point in pixel coordinates onto the element's plane.
	/// @param[in-out] point The point to project in, and the resulting projected point out.
	/// @return True on success, false if transformation matrix is singular.
	bool Project(Point& point) const noexcept;

	/// Add a key to an animation, extending its duration.
	/// If no animation exists for the given property name, the call will be ignored.
	/// @return True if a new animation key was added.
	bool AddAnimationKey(const String& property_name, const Property& target_value, float duration, Tween tween = Tween{});
	
	///@}

	/** @name Pseudo-classes
	 */
	//@{
	/// Sets or removes a pseudo-class on the element.
	/// @param[in] pseudo_class The pseudo class to activate or deactivate.
	/// @param[in] activate True if the pseudo-class is to be activated, false to be deactivated.
	void SetPseudoClass(const String& pseudo_class, bool activate);
	/// Checks if a specific pseudo-class has been set on the element.
	/// @param[in] pseudo_class The name of the pseudo-class to check for.
	/// @return True if the pseudo-class is set on the element, false if not.
	bool IsPseudoClassSet(const String& pseudo_class) const;
	/// Checks if a complete set of pseudo-classes are set on the element.
	/// @param[in] pseudo_classes The set of pseudo-classes to check for.
	/// @return True if all of the pseudo-classes are set, false if not.
	bool ArePseudoClassesSet(const PseudoClassList& pseudo_classes) const;
	/// Gets a list of the current active pseudo-classes.
	/// @return The list of active pseudo-classes.
	const PseudoClassList& GetActivePseudoClasses() const;
	//@}

	/** @name Attributes
	 */
	//@{
	/// Sets an attribute on the element.
	/// @param[in] name Name of the attribute.
	/// @param[in] value Value of the attribute.
	template< typename T >
	void SetAttribute(const String& name, const T& value);
	/// Gets the specified attribute.
	/// @param[in] name Name of the attribute to retrieve.
	/// @return A variant representing the attribute, or nullptr if the attribute doesn't exist.
	Variant* GetAttribute(const String& name);
	/// Gets the specified attribute, with default value.
	/// @param[in] name Name of the attribute to retrieve.
	/// @param[in] default_value Value to return if the attribute doesn't exist.
	template< typename T >
	T GetAttribute(const String& name, const T& default_value) const;
	/// Checks if the element has a certain attribute.
	/// @param[in] name The name of the attribute to check for.
	/// @return True if the element has the given attribute, false if not.
	bool HasAttribute(const String& name) const;
	/// Removes the attribute from the element.
	/// @param[in] name Name of the attribute.
	void RemoveAttribute(const String& name);
	/// Set a group of attributes.
	/// @param[in] attributes Attributes to set.
	void SetAttributes(const ElementAttributes& attributes);
	/// Get the attributes of the element.
	/// @return The attributes
	const ElementAttributes& GetAttributes() const { return attributes; }
	/// Returns the number of attributes on the element.
	/// @return The number of attributes on the element.
	int GetNumAttributes() const;
	//@}


	/// Returns the element's context.
	/// @return The context this element's document exists within.
	Context* GetContext() const;

	/** @name DOM Properties
	 */
	//@{

	/// Gets the name of the element.
	/// @return The name of the element.
	const String& GetTagName() const;

	/// Gets the id of the element.
	/// @return The element's id.
	const String& GetId() const;
	/// Sets the id of the element.
	/// @param[in] id The new id of the element.
	void SetId(const String& id);

	/// Gets the object representing the declarations of an element's style attributes.
	/// @return The element's style.
	ElementStyle* GetStyle() const;

	/// Gets the document this element belongs to.
	/// @return This element's document.
	Document* GetOwnerDocument() const;

	/// Get the child element at the given index.
	/// @param[in] index Index of child to get.
	/// @return The child element at the given index.
	Element* GetChild(int index) const;
	/// Get the current number of children in this element
	/// @param[in] include_non_dom_elements True if the caller wants to include the non DOM children. Only set this to true if you know what you're doing!
	/// @return The number of children.
	int GetNumChildren() const;

	String GetInnerRML() const;
	String GetOuterRML() const;
	void SetInnerRML(const String& rml);

	//@}

	/** @name DOM Methods
	 */
	//@{

	/// Adds an event listener to this element.
	/// @param[in] event Event to attach to.
	/// @param[in] listener The listener object to be attached.
	/// @param[in] in_capture_phase True to attach in the capture phase, false in bubble phase.
	/// @lifetime The added listener must stay alive until after the dispatched call from EventListener::OnDetach(). This occurs
	///     eg. when the element is destroyed or when RemoveEventListener() is called with the same parameters passed here.
	void AddEventListener(const String& event, EventListener* listener, bool in_capture_phase = false);
	/// Adds an event listener to this element by id.
	/// @lifetime The added listener must stay alive until after the dispatched call from EventListener::OnDetach(). This occurs
	///     eg. when the element is destroyed or when RemoveEventListener() is called with the same parameters passed here.
	void AddEventListener(EventId id, EventListener* listener, bool in_capture_phase = false);
	/// Removes an event listener from this element.
	/// @param[in] event Event to detach from.
	/// @param[in] listener The listener object to be detached.
	/// @param[in] in_capture_phase True to detach from the capture phase, false from the bubble phase.
	void RemoveEventListener(const String& event, EventListener* listener, bool in_capture_phase = false);
	/// Removes an event listener from this element by id.
	void RemoveEventListener(EventId id, EventListener* listener, bool in_capture_phase = false);
	/// Sends an event to this element.
	/// @param[in] type Event type in string form.
	/// @param[in] parameters The event parameters.
	/// @return True if the event was not consumed (ie, was prevented from propagating by an element), false if it was.
	bool DispatchEvent(const String& type, const Dictionary& parameters);
	/// Sends an event to this element, overriding the default behavior for the given event type.
	bool DispatchEvent(const String& type, const Dictionary& parameters, bool interruptible, bool bubbles = true);
	/// Sends an event to this element by event id.
	bool DispatchEvent(EventId id, const Dictionary& parameters);

	/// Append a child to this element.
	/// @param[in] element The element to append as a child.
	/// @param[in] dom_element True if the element is to be part of the DOM, false otherwise. Only set this to false if you know what you're doing!
	Element* AppendChild(ElementPtr element);
	/// Adds a child to this element, directly after the adjacent element. The new element inherits the DOM/non-DOM
	/// status from the adjacent element.
	/// @param[in] element Element to insert into the this element.
	/// @param[in] adjacent_element The element to insert directly before.
	Element* InsertBefore(ElementPtr element, Element* adjacent_element);
	/// Remove a child element from this element.
	/// @param[in] The element to remove.
	/// @returns A unique pointer to the element if found, discard the result to immediately destroy.
	ElementPtr RemoveChild(Element* element);

	/// Get a child element by its ID.
	/// @param[in] id Id of the the child element
	/// @return The child of this element with the given ID, or nullptr if no such child exists.
	Element* GetElementById(const String& id);
	/// Get all descendant elements with the given tag.
	/// @param[out] elements Resulting elements.
	/// @param[in] tag Tag to search for.
	void GetElementsByTagName(ElementList& elements, const String& tag);
	/// Get all descendant elements with the given class set on them.
	/// @param[out] elements Resulting elements.
	/// @param[in] tag Tag to search for.
	void GetElementsByClassName(ElementList& elements, const String& class_name);
	/// Returns the first descendent element matching the RCSS selector query.
	/// @param[in] selectors The selector or comma-separated selectors to match against.
	/// @return The first matching element during a depth-first traversal.
	/// @performance Prefer GetElementById/TagName/ClassName whenever possible.
	Element* QuerySelector(const String& selector);
	/// Returns all descendent elements matching the RCSS selector query.
	/// @param[out] elements The list of matching elements.
	/// @param[in] selectors The selector or comma-separated selectors to match against.
	/// @performance Prefer GetElementById/TagName/ClassName whenever possible.
	void QuerySelectorAll(ElementList& elements, const String& selectors);


	//@}

	/**
		@name Internal Functions
	 */
	//@{
	/// Access the event dispatcher for this element.
	EventDispatcher* GetEventDispatcher() const;
	/// Returns event types with number of listeners for debugging.
	String GetEventDispatcherSummary() const;
	/// Returns the data model of this element.
	DataModel* GetDataModel() const;
	//@}
	
	/// Returns true if this element has clipping enabled
	bool IsClippingEnabled();

	/// Called when an emitted event propagates to this element, for event types with default actions.
	/// Note: See 'EventSpecification' for the events that call this function and during which phase.
	/// @param[in] event The event to process.
	virtual void ProcessDefaultAction(Event& event);

	/// Return the computed values of the element's properties. These values are updated as appropriate on every Context::Update.
	const ComputedValues& GetComputedValues() const;

	void UpdateBounds();
	void UpdateChildrenBounds();
	void SetParent(Element* parent);
	Element* GetElementAtPoint(Point point, const Element* ignore_element = nullptr);
	Rect GetClippingRegion();
	const Matrix4f* GetTransform();
	void SetClipRegion(const Matrix4f* matrix);

protected:
	void Update();

	void UpdateProperties();
	void OnAttributeChange(const ElementAttributes& changed_attributes);

	virtual void OnRender() override;
	virtual void OnChange(const PropertyIdSet& changed_properties) override;

protected:
	void SetDataModel(DataModel* new_data_model);

	void UpdateStackingContext();
	void DirtyStackingContext();

	void DirtyStructure();
	void UpdateStructure();

	void DirtyTransform();
	void DirtyPerspective();
	void UpdateTransform();
	void UpdatePerspective();
	void UpdateMatrix();
	
	/// Start an animation, replacing any existing animations of the same property name. If start_value is null, the element's current value is used.
	void StartAnimation(PropertyId property_id, const Property * start_value, int num_iterations, bool alternate_direction, float delay, bool initiated_by_animation_property);

	/// Add a key to an animation, extending its duration. If target_value is null, the element's current value is used.
	bool AddAnimationKeyTime(PropertyId property_id, const Property * target_value, float time, Tween tween);

	/// Start a transition of the given property on this element.
	/// If an animation exists for the property, the call will be ignored. If a transition exists for this property, it will be replaced.
	/// @return True if the transition was added or replaced.
	bool StartTransition(const Transition& transition, const Property& start_value, const Property& target_value, bool remove_when_complete);

	/// Removes all transitions that are no longer part of the element's 'transition' property.
	void HandleTransitionProperty();

	/// Starts new animations and removes animations no longer part of the element's 'animation' property.
	void HandleAnimationProperty();

	/// Advances the animations (including transitions) forward in time.
	void AdvanceAnimations();

	// Original tag this element came from.
	String tag;

	// The optional, unique ID of this object.
	String id;

	// The owning document
	Document* owner_document;

	// Active data model for this element.
	DataModel* data_model;
	// Attributes on this element.
	ElementAttributes attributes;

	OwnedElementList children;

	float z_index;

	ElementList stacking_context;
	bool stacking_context_dirty;

	bool structure_dirty;

	bool dirty_transform;
	bool dirty_perspective;
	Matrix4f transform;
	UniquePtr<Matrix4f> perspective;
	mutable bool have_inv_transform = true;
	mutable UniquePtr<Matrix4f> inv_transform;

	ElementAnimationList animations;
	bool dirty_animation;
	bool dirty_transition;

	ElementMeta* meta;

	bool dirty_background = false;
	bool dirty_border = false;
	bool dirty_image = false;
	UniquePtr<Geometry> geometry_border;
	UniquePtr<Geometry> geometry_image;
	Geometry::Path padding_edge;

	float font_size = 16.f;

	friend class Rml::ElementStyle;
	friend class Rml::Document;
};

} // namespace Rml

#include "Element.inl"

#endif
