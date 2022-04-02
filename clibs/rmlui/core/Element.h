#pragma once

#include <core/Layout.h>
#include <core/ComputedValues.h>
#include <core/ObserverPtr.h>
#include <core/Property.h>
#include <core/Types.h>
#include <core/Tween.h>
#include <core/Geometry.h>
#include <core/Node.h>
#include <core/PropertyIdSet.h>
#include <core/PropertyDictionary.h>
#include <optional>

namespace Rml {

class DataModel;
class Document;
class Element;
class ElementAnimation;
class EventListener;
class Geometry;
class StyleSheet;
class StyleSheetPropertyDictionary;
struct HtmlElement;

using ElementList = std::vector<Element*>;
using ElementAttributes = std::unordered_map<std::string, std::string>;

class Element : public Node, public EnableObserverPtr<Element> {
public:
	Element(Document* owner, const std::string& tag);
	virtual ~Element();

	const StyleSheet& GetStyleSheet() const;
	std::string GetAddress(bool include_pseudo_classes = false, bool include_parents = true) const;
	bool IsPointWithinElement(Point point);

	float GetFontSize() const;
	float GetOpacity();
	bool UpdataFontSize();

	void SetAttribute(const std::string& name, const std::string& value);
	const std::string* GetAttribute(const std::string& name) const;
	bool HasAttribute(const std::string& name) const;
	void RemoveAttribute(const std::string& name);
	const ElementAttributes& GetAttributes() const { return attributes; }

	bool Project(Point& point) const noexcept;
	const std::string& GetTagName() const;
	const std::string& GetId() const;
	void SetId(const std::string& id);
	Document* GetOwnerDocument() const;

	void InstanceOuter(const HtmlElement& html);
	void InstanceInner(const HtmlElement& html);
	void NotifyCustomElement();

	void AddEventListener(EventListener* listener);
	void RemoveEventListener(EventListener* listener);
	bool DispatchEvent(const std::string& type, int parameters, bool interruptible, bool bubbles);
	void RemoveAllEvents();
	std::vector<EventListener*> const& GetEventListeners() const;

	void   AppendChild(Node* node);
	void   RemoveChild(Node* node);
	size_t GetChildNodeIndex(Node* node) const;
	void   InsertBefore(Node* child, Node* adjacent);
	Node*  GetPreviousSibling();
	void   RemoveAllChildren();

	auto const& Children() const { return children; }
	auto const& ChildNodes() const { return childnodes; }
	auto&       Children() { return children; }
	auto&       ChildNodes() { return childnodes; }

	Node* GetChildNode(size_t index) const;
	size_t GetNumChildNodes() const;

	Element* GetElementById(const std::string& id);
	void GetElementsByTagName(ElementList& elements, const std::string& tag);
	void GetElementsByClassName(ElementList& elements, const std::string& class_name);

	void Update();
	void UpdateRender();
	void SetRednerStatus();

	Size GetScrollOffset() const;
	float GetScrollLeft() const;
	float GetScrollTop() const;
	void SetScrollLeft(float v);
	void SetScrollTop(float v);
	void SetScrollInsets(const EdgeInsets<float>& insets);
	void UpdateScrollOffset(Size& scrollOffset) const;

	void SetPseudoClass(PseudoClass pseudo_class, bool activate);
	bool IsPseudoClassSet(PseudoClassSet pseudo_class) const;
	PseudoClassSet GetActivePseudoClasses() const;
	void SetClass(const std::string& class_name, bool activate);
	bool IsClassSet(const std::string& class_name) const;
	void SetClassName(const std::string& class_names);
	std::string GetClassName() const;
	void DirtyPropertiesWithUnitRecursive(PropertyUnit unit);

	void UpdateDefinition();
	void DirtyDefinition();
	void DirtyInheritedProperties();
	void ForeachProperties(std::function<void(PropertyId id, const Property& property)> f);
	void DirtyProperty(PropertyId id);
	void DirtyProperties(const PropertyIdSet& properties);

	void SetProperty(PropertyId id, const Property* property = nullptr);
	void SetAnimationProperty(PropertyId id, const Property* property = nullptr);

	const Property* GetProperty(PropertyId id) const;
	const Property* GetComputedProperty(PropertyId id) const;
	const Property* GetComputedLocalProperty(PropertyId id) const;
	const Property* GetAnimationProperty(PropertyId id) const;
	const Transitions* GetTransition(const PropertyDictionary* def = nullptr) const;

	void SetProperty(const std::string& name, std::optional<std::string> value = {});
	std::optional<std::string> GetProperty(const std::string& name) const;

	void TransitionPropertyChanges(const PropertyIdSet & properties, const PropertyDictionary& new_definition);
	void TransitionPropertyChanges(const Transitions* transitions, PropertyId id, const Property& old_property);

	void UpdateProperties();
	void UpdateAnimations();

	const EdgeInsets<float>& GetPadding() const;
	const EdgeInsets<float>& GetBorder() const;

	void SetParentNode(Element* parent) override;
	void SetDataModel(DataModel* data_model) override;
	Node* Clone(bool deep = true) const override;
	void CalculateLayout() override;
	void Render() override;
	float GetZIndex() const override;
	Element* ElementFromPoint(Point point) override;
	std::string GetInnerHTML() const override;
	std::string GetOuterHTML() const override;
	void SetInnerHTML(const std::string& html) override;
	void SetOuterHTML(const std::string& html) override;
	const Rect& GetContentRect() const override;

	virtual void ChangedProperties(const PropertyIdSet& changed_properties);

protected:
	void OnAttributeChange(const ElementAttributes& changed_attributes);
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
	void UpdateProperty(PropertyId id, const Property* property = nullptr);

	void StartAnimation(PropertyId property_id, const Property * start_value, int num_iterations, bool alternate_direction, float delay);
	bool AddAnimationKeyTime(PropertyId property_id, const Property* target_value, float time, Tween tween);
	bool StartTransition(PropertyId id, const Transition& transition, const Property& start_value, const Property& target_value);
	void HandleTransitionProperty();
	void HandleAnimationProperty();
	void AdvanceAnimations();

	std::string tag;
	std::string id;
	Document* owner_document;
	ElementAttributes attributes;
	std::vector<Element*> children;
	std::vector<std::unique_ptr<Node>> childnodes;
	float z_index = 0;
	std::vector<Node*> stacking_context;
	std::unique_ptr<glm::mat4x4> perspective;
	mutable bool have_inv_transform = true;
	mutable std::unique_ptr<glm::mat4x4> inv_transform;
	std::vector<ElementAnimation> animations;
	std::vector<std::string> classes;
	PseudoClassSet pseudo_classes = 0;
	std::vector<EventListener*> listeners;
	std::unique_ptr<Geometry> geometry_background;
	std::unique_ptr<TextureGeometry> geometry_image;
	float font_size = 16.f;
	PropertyDictionary animation_properties;
	PropertyDictionary inline_properties;
	SharedPtr<StyleSheetPropertyDictionary> definition_properties;
	PropertyIdSet dirty_properties;
	glm::mat4x4 transform;
	Rect content_rect;
	EdgeInsets<float> padding{};
	EdgeInsets<float> border{};
	EdgeInsets<float> scroll_insets{};
	Geometry::Path padding_edge;
	struct Clip {
		enum class Type : uint8_t {
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
};

}
