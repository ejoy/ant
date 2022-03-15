#pragma once

#include "Layout.h"
#include "ComputedValues.h"
#include "ObserverPtr.h"
#include "Property.h"
#include "Types.h"
#include "Tween.h"
#include "Geometry.h"
#include "Node.h"
#include "PropertyIdSet.h"
#include <glm/glm.hpp>

namespace Rml {

class DataModel;
class EventListener;
class Document;
class StyleSheet;
class Geometry;
class StyleSheetPropertyDictionary;

class Element : public Node, public EnableObserverPtr<Element> {
public:
	Element(Document* owner, const std::string& tag);
	virtual ~Element();

	virtual const std::shared_ptr<StyleSheet>& GetStyleSheet() const;
	std::string GetAddress(bool include_pseudo_classes = false, bool include_parents = true) const;
	bool IsPointWithinElement(Point point);

	float GetZIndex() const;
	float GetFontSize() const;
	float GetOpacity();
	bool UpdataFontSize();

	void SetAttribute(const std::string& name, const std::string& value);
	const std::string* GetAttribute(const std::string& name) const;
	bool HasAttribute(const std::string& name) const;
	void RemoveAttribute(const std::string& name);
	void SetAttributes(const ElementAttributes& attributes);
	const ElementAttributes& GetAttributes() const { return attributes; }

	bool Project(Point& point) const noexcept;
	const std::string& GetTagName() const;
	const std::string& GetId() const;
	void SetId(const std::string& id);
	Document* GetOwnerDocument() const;
	Element* GetChild(int index) const;
	int GetNumChildren() const;

	std::string GetInnerRML() const;
	std::string GetOuterRML() const;
	void SetInnerRML(const std::string& rml);
	bool CreateTextNode(const std::string& str);

	void AddEventListener(EventListener* listener);
	void RemoveEventListener(EventListener* listener);
	bool DispatchEvent(const std::string& type, int parameters, bool interruptible, bool bubbles);
	void RemoveAllEvents();
	std::vector<EventListener*> const& GetEventListeners() const;

	Element* AppendChild(ElementPtr element);
	Element* InsertBefore(ElementPtr element, Element* adjacent_element);
	ElementPtr RemoveChild(Element* element);
	Element* GetElementById(const std::string& id);
	void GetElementsByTagName(ElementList& elements, const std::string& tag);
	void GetElementsByClassName(ElementList& elements, const std::string& class_name);
	Element* QuerySelector(const std::string& selector);
	void QuerySelectorAll(ElementList& elements, const std::string& selectors);

	DataModel* GetDataModel() const;
	const Style::ComputedValues& GetComputedValues() const;

	void UpdateLayout();
	void SetParent(Element* parent);
	Element* ElementFromPoint(Point point);
	void SetRednerStatus();

	Size GetScrollOffset() const;

	void SetPseudoClass(PseudoClass pseudo_class, bool activate);
	bool IsPseudoClassSet(PseudoClassSet pseudo_class) const;
	PseudoClassSet GetActivePseudoClasses() const;
	void SetClass(const std::string& class_name, bool activate);
	bool IsClassSet(const std::string& class_name) const;
	void SetClassNames(const std::string& class_names);
	std::string GetClassNames() const;
	void DirtyPropertiesWithUnitRecursive(Property::UnitMark mark);

	void UpdateDefinition();
	void DirtyDefinition();
	void DirtyInheritedProperties();
	void DirtyProperties(Property::UnitMark mark);
	void ForeachProperties(std::function<void(PropertyId id, const Property& property)> f);
	void DirtyProperty(PropertyId id);
	void DirtyProperties(const PropertyIdSet& properties);

	void SetProperty(PropertyId id, const Property& property);
	void SetPropertyImmediate(PropertyId id, const Property& property);
	void SetPropertyImmediate(const std::string& name, const std::string& value);
	void SetAnimationProperty(PropertyId id, const Property& property);

	void RemoveProperty(PropertyId id);
	void RemoveAnimationProperty(PropertyId id);

	const Property* GetProperty(PropertyId id) const;
	const Property* GetComputedProperty(PropertyId id) const;
	const Property* GetComputedLocalProperty(PropertyId id) const;
	const Property* GetAnimationProperty(PropertyId id) const;
	const TransitionList* GetTransition(const PropertyDictionary* def = nullptr) const;

	void SetProperty(const std::string& name, std::optional<std::string> value = {});
	std::optional<std::string> GetProperty(const std::string& name) const;

	void TransitionPropertyChanges(const PropertyIdSet & properties, const PropertyDictionary& new_definition);
	void TransitionPropertyChanges(const TransitionList* transition_list, PropertyId id, const Property& old_property);

protected:
	void Update();
	void UpdateProperties();
	void OnAttributeChange(const ElementAttributes& changed_attributes);
	void Render() override;
	void OnChange(const PropertyIdSet& changed_properties) override;
	void SetDataModel(DataModel* new_data_model);
	void UpdateStackingContext();
	void DirtyStackingContext();
	void DirtyStructure();
	void UpdateStructure();
	void DirtyPerspective();
	void UpdateTransform();
	void UpdatePerspective();
	void UpdateGeometry();
	void DirtyTransform();
	void DirtyClip();
	void UpdateClip();

	void StartAnimation(PropertyId property_id, const Property * start_value, int num_iterations, bool alternate_direction, float delay, bool initiated_by_animation_property);
	bool AddAnimationKeyTime(PropertyId property_id, const Property* target_value, float time, Tween tween);
	bool StartTransition(const Transition& transition, const Property& start_value, const Property& target_value);
	void HandleTransitionProperty();
	void HandleAnimationProperty();
	void AdvanceAnimations();

	std::string tag;
	std::string id;
	Document* owner_document;
	DataModel* data_model = nullptr;
	ElementAttributes attributes;
	OwnedElementList children;
	float z_index = 0;
	ElementList stacking_context;
	std::unique_ptr<glm::mat4x4> perspective;
	mutable bool have_inv_transform = true;
	mutable std::unique_ptr<glm::mat4x4> inv_transform;
	ElementAnimationList animations;
	std::vector<std::string> classes;
	PseudoClassSet pseudo_classes = 0;
	Style::ComputedValues computed_values;
	std::vector<EventListener*> listeners;
	std::unique_ptr<Geometry> geometry_background;
	std::unique_ptr<Geometry> geometry_image;
	Geometry::Path padding_edge;
	float font_size = 16.f;
	PropertyDictionary                  animation_properties;
	PropertyDictionary                  inline_properties;
	std::shared_ptr<StyleSheetPropertyDictionary> definition_properties;
	PropertyIdSet dirty_properties;
	glm::mat4x4 transform;
	struct Clip {
		enum class Type {
			None,
			Scissor,
			Shader,
		} type = Type::None;
		union {
			glm::u16vec4 scissor;
			glm::vec4 shader[2];
		};
	} clip;
	void UnionClip(Clip& clip);

	bool dirty_transform = false;
	bool dirty_clip = false;
	bool dirty_stacking_context = false;
	bool dirty_structure = false;
	bool dirty_perspective = false;
	bool dirty_animation = false;
	bool dirty_transition = false;
	bool dirty_background = false;
	bool dirty_image = false;
	bool dirty_definition = true;

	friend class Rml::Document;
};

}
