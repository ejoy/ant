#include <core/Element.h>
#include <core/Core.h>
#include <core/Document.h>
#include <core/ElementAnimation.h>
#include <core/ElementBackgroundBorder.h>
#include <core/ElementBackgroundImage.h>
#include <core/Event.h>
#include <core/EventDispatcher.h>
#include <core/EventListener.h>
#include <core/HtmlParser.h>
#include <core/Interface.h>
#include <core/Log.h>
#include <core/Property.h>
#include <core/Stream.h>
#include <core/StringUtilities.h>
#include <core/StyleSheetParser.h>
#include <core/StyleSheetSpecification.h>
#include <core/Text.h>
#include <core/Transform.h>
#include <algorithm>
#include <cmath>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtx/transform.hpp>
#include <binding/luaplugin.h>

namespace Rml {

static PropertyFloat ComputeOrigin(const std::optional<Property>& p) {
	if (p->Has<PropertyKeyword>()) {
		switch (p->Get<PropertyKeyword>()) {
		default:
		case 0 /* left/top     */: return { 0.0f, PropertyUnit::PERCENT };
		case 1 /* center       */: return { 50.0f, PropertyUnit::PERCENT };
		case 2 /* right/bottom */: return { 100.0f, PropertyUnit::PERCENT };
		}
	}
	return p->Get<PropertyFloat>();
}

static glm::vec3 PerspectiveOrigin(Element* e) {
	auto originX = e->GetComputedProperty(PropertyId::PerspectiveOriginX);
	auto originY = e->GetComputedProperty(PropertyId::PerspectiveOriginY);
	float x = ComputeOrigin(originX).ComputeW(e);
	float y = ComputeOrigin(originY).ComputeH(e);
	return { x, y, 0.f };
}

Element::Element(Document* owner, const std::string& tag)
	: Node(Layout::UseElement {})
	, tag(tag)
	, owner_document(owner)
{
	dirty.insert(Dirty::Definition);
	assert(tag == StringUtilities::ToLower(tag));
	assert(owner);
}

Element::~Element() {
	GetPlugin()->OnDestroyNode(GetOwnerDocument(), this);
	assert(parent == nullptr);
	assert(childnodes.empty());

	auto& c = Style::Instance();
	c.Release(animation_properties);
	c.Release(inline_properties);
	c.Release(definition_properties);
	c.Release(local_properties);
	c.Release(global_properties);
}

void Element::Update() {
	if (!IsVisible()) {
		return;
	}
	UpdateStructure();
	UpdateDefinition();
	UpdateProperties();
	HandleTransitionProperty();
	HandleAnimationProperty();
	for (auto& child : children) {
		child->Update();
	}
}

void Element::UpdateAnimations(float delta) {
	if (!IsVisible()) {
		return;
	}
	AdvanceAnimations(delta);
	for (auto& child : children) {
		child->UpdateAnimations(delta);
	}
}

void Element::Render() {
	if (!IsVisible()) {
		return;
	}
	UpdateTransform();
	UpdatePerspective();
	UpdateClip();
	UpdateGeometry();
	UpdateStackingContext();

	size_t i = 0;
	for (; i < stacking_context.size() && stacking_context[i]->GetZIndex() < 0; ++i) {
		stacking_context[i]->Render();
	}
	SetRenderStatus();
	if (geometry_background && *geometry_background) {
		geometry_background->Render();
	}
	if (geometry_image && *geometry_image) {
		geometry_image->Render();
	}
	for (; i < stacking_context.size(); ++i) {
		stacking_context[i]->Render();
	}
}

const StyleSheet& Element::GetStyleSheet() const {
	return GetOwnerDocument()->GetStyleSheet();
}

std::string Element::GetAddress(bool include_pseudo_classes, bool include_parents) const {
	std::string address(tag);

	if (!id.empty()) {
		address += "#";
		address += id;
	}

	std::string class_names;
	for (size_t i = 0; i < classes.size(); i++) {
		if (i != 0) {
			class_names += ".";
		}
		class_names += classes[i];
	}
	if (!class_names.empty()) {
		address += ".";
		address += class_names;
	}

	if (include_pseudo_classes) {
		PseudoClassSet pseudo_classes = GetActivePseudoClasses();
		if (pseudo_classes & PseudoClass::Active) { address += ":active"; }
		if (pseudo_classes & PseudoClass::Hover) { address += ":hover"; }
	}

	if (include_parents && parent) {
		address += " < ";
		return address + parent->GetAddress(include_pseudo_classes, true);
	}
	else
		return address;
}

bool Element::IgnorePointerEvents() const {
	return GetComputedProperty(PropertyId::PointerEvents)->Get<Style::PointerEvents>() == Style::PointerEvents::None;
}

float Element::GetZIndex() const {
	return GetComputedProperty(PropertyId::ZIndex)->Get<PropertyFloat>().value;
}

float Element::GetFontSize() const {
	return font_size;
}

static float ComputeFontsize(const Property& property, Element* element) {
	PropertyFloat fv = property.Get<PropertyFloat>();
	if (fv.unit == PropertyUnit::PERCENT || fv.unit == PropertyUnit::EM) {
		float fontSize = 16.f;
		Element* parent = element->GetParentNode();
		if (parent) {
			fontSize = parent->GetFontSize();
		}
		if (fv.unit == PropertyUnit::PERCENT) {
			return fontSize * 0.01f * fv.value;
		}
		return fontSize * fv.value;
	}
	if (fv.unit == PropertyUnit::REM) {
		if (element == element->GetOwnerDocument()->GetBody()) {
			return fv.value * 16;
		}
	}
	return fv.Compute(element);
}

bool Element::UpdataFontSize() {
	float new_size = font_size;
	if (auto p = GetLocalProperty(PropertyId::FontSize))
		new_size = ComputeFontsize(*p, this);
	else if (parent) {
		new_size = parent->GetFontSize();
	}
	if (new_size != font_size) {
		font_size = new_size;
		return true;
	}
	return false;
}

bool Element::IsGray() {
	return GetComputedProperty(PropertyId::Filter)->Get<Style::Filter>() == Style::Filter::Gray;
}

float Element::GetOpacity() {
	auto property = GetComputedProperty(PropertyId::Opacity);
	return property->Get<PropertyFloat>().value;
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

void Element::SetAttribute(const std::string& name, const std::string& value) {
	auto it = attributes.find(name);
	if (it == attributes.end() || it->second != value) {
		attributes[name] = value;
		ElementAttributes changed_attributes;
		changed_attributes.emplace(name, value);
		OnAttributeChange(changed_attributes);
	}
}

const std::string* Element::GetAttribute(const std::string& name) const {
	auto it = attributes.find(name);
	if (it == attributes.end()) {
		return nullptr;
	}
	return &it->second;
}

bool Element::HasAttribute(const std::string& name) const {
	return attributes.find(name) != attributes.end();
}

void Element::RemoveAttribute(const std::string& name) {
	auto it = attributes.find(name);
	if (it != attributes.end()) {
		attributes.erase(it);

		ElementAttributes changed_attributes;
		changed_attributes.emplace(name, std::string());
		OnAttributeChange(changed_attributes);
	}
}

const std::string& Element::GetTagName() const {
	return tag;
}

const std::string& Element::GetId() const {
	return id;
}

void Element::SetId(const std::string& _id) {
	SetAttribute("id", _id);
}

Document* Element::GetOwnerDocument() const {
	return owner_document;
}

Node* Element::GetChildNode(size_t index) const {
	if (index < 0 || index >= childnodes.size())
		return nullptr;
	return childnodes[index].get();
}

size_t Element::GetNumChildNodes() const {
	return childnodes.size();
}

void Element::SetInnerHTML(const std::string& html) {
	if (html.empty()) {
		RemoveAllChildren();
		return;
	}
	try {
		HtmlParser parser;
		HtmlElement dom = parser.Parse(html, true);
		InstanceInner(dom);
	}
	catch (HtmlParserException& e) {
		Log::Message(Log::Level::Error, "%s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		return;
	}
}

void Element::SetOuterHTML(const std::string& html) {
	if (html.empty()) {
		tag.clear();
		attributes.clear();
		RemoveAllChildren();
		return;
	}
	try {
		HtmlParser parser;
		HtmlElement dom = parser.Parse(html, false);
		InstanceOuter(dom);
	}
	catch (HtmlParserException& e) {
		Log::Message(Log::Level::Error, "%s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		return;
	}
}

template<class> inline constexpr bool always_false_v = false;

void Element::InstanceOuter(const HtmlElement& html) {
	tag = html.tag;
	attributes.clear();
	for (auto const& [name, value] : html.attributes) {
		attributes[name] = value;
	}
	OnAttributeChange(attributes);
	InstanceInner(html);
}

void Element::InstanceInner(const HtmlElement& html) {
	RemoveAllChildren();
	for (auto const& node : html.children) {
		std::visit([this](auto&& arg) {
			using T = std::decay_t<decltype(arg)>;
			if constexpr (std::is_same_v<T, HtmlElement>) {
				Element* e = owner_document->CreateElement(arg.tag);
				if (e) {
					e->InstanceOuter(arg);
					e->NotifyCustomElement();
					AppendChild(e);
				}
			}
			else if constexpr (std::is_same_v<T, HtmlString>) {
				if(this->tag == "richtext"){
					RichText* e = owner_document->CreateRichTextNode(arg);
					if(e){
						AppendChild(e);
					}
				}
				else{
					Text* e = owner_document->CreateTextNode(arg);
					if(e){
						AppendChild(e);
					}					
				}
			}
			else {
				static_assert(always_false_v<T>, "non-exhaustive visitor!");
			}
		}, node);
	}
}

Node* Element::Clone(bool deep) const {
	Element* e = owner_document->CreateElement(tag);
	if (e) {
		for (auto const& [name, value] : attributes) {
			e->attributes[name] = value;
		}
		e->OnAttributeChange(attributes);
		if (deep) {
			for (auto const& child : childnodes) {
				e->AppendChild(child->Clone(true));
			}
		}
		e->NotifyCustomElement();
	}
	return e;
}

void Element::NotifyCustomElement() {
	owner_document->NotifyCustomElement(this);
}

void Element::AppendChild(Node* node, uint32_t index) {
	Element* p = node->GetParentNode();
	if (p) {
		p->DetachChild(node).release();
	}
	if (index > childnodes.size()) {
		index = (uint32_t)childnodes.size();
	}
	GetLayout().InsertChild(node->GetLayout(), index);
	childnodes.emplace_back(node);
	if (node->GetType() == Layout::Type::Element) {
		auto e = static_cast<Element*>(node);
		children.emplace_back(e);
	}
	node->SetParentNode(this);
	DirtyStackingContext();
	DirtyStructure();
}

std::unique_ptr<Node> Element::DetachChild(Node* node) {
	size_t index = GetChildNodeIndex(node);
	if (index == size_t(-1)) {
		return nullptr;
	}
	auto detached_child = std::move(childnodes[index]);
	childnodes.erase(childnodes.begin() + index);
	
	if (node->GetType() == Layout::Type::Element) {
		auto e = static_cast<Element*>(node);
		for (auto it = children.begin(); it != children.end(); ++it) {
			if (*it == e) {
				children.erase(it);
				break;
			}
		}
	}
	node->SetParentNode(nullptr);
	GetLayout().RemoveChild(node->GetLayout());
	DirtyStackingContext();
	DirtyStructure();
	return detached_child;
}

void Element::RemoveChild(Node* node) {
	auto detached_child = DetachChild(node);
	if (detached_child) {
		if (node->GetType() == Layout::Type::Element) {
			auto e = static_cast<Element*>(node);
			e->RemoveAllChildren();
		}
		GetOwnerDocument()->RecycleNode(std::move(detached_child));
	}
}

size_t Element::GetChildNodeIndex(Node* node) const {
	for (size_t i = 0; i < childnodes.size(); ++i) {
		if (childnodes[i].get() == node) {
			return i;
		}
	}
	return size_t(-1);
}

void Element::InsertBefore(Node* node, Node* adjacent) {
	size_t index = GetChildNodeIndex(adjacent);
	if (index == size_t(-1)) {
		AppendChild(node);
		return;
	}

	GetLayout().InsertChild(node->GetLayout(), (uint32_t)index);
	childnodes.emplace(childnodes.begin() + index, node);
	if (node->GetType() == Layout::Type::Element) {
		auto e = static_cast<Element*>(node);
		children.emplace_back(e);
	}
	node->SetParentNode(this);
	DirtyStackingContext();
	DirtyStructure();
}

Node* Element::GetPreviousSibling() {
	if (!parent) {
		return nullptr;
	}
	size_t index = parent->GetChildNodeIndex(this);
	if (index == size_t(-1)) {
		return nullptr;
	}
	if (index == 0) {
		return nullptr;
	}
	return parent->childnodes[index-1].get();
}

void Element::RemoveAllChildren() {
	for (auto& child : children) {
		child->RemoveAllChildren();
	}
	for (auto&& child : childnodes) {
		child->SetParentNode(nullptr);
		GetOwnerDocument()->RecycleNode(std::move(child));
	}
	children.clear();
	childnodes.clear();
	GetLayout().RemoveAllChildren();
	DirtyStackingContext();
	DirtyStructure();
}

Element* Element::GetElementById(const std::string& id) {
	if (GetId() == id) {
		return this;
	}
	for (auto& child : children) {
		Element* e = child->GetElementById(id);
		if (e) {
			return e;
		}
	}
	return nullptr;
}

void Element::GetElementsByTagName(ElementList& elements, const std::string& tag) {
	if (GetTagName() == tag) {
		elements.push_back(this);
	}
	for (auto& child : children) {
		child->GetElementsByTagName(elements, tag);
	}
}

void Element::GetElementsByClassName(ElementList& elements, const std::string& class_name) {
	if (GetTagName() == tag) {
		if (IsClassSet(class_name)) {
			elements.push_back(this);
		}
	}
	for (auto& child : children) {
		child->GetElementsByClassName(elements, class_name);
	}
}

void Element::OnAttributeChange(const ElementAttributes& changed_attributes) {
	auto it = changed_attributes.find("id");
	if (it != changed_attributes.end()) {
		id = it->second;
		Update();
	}

	it = changed_attributes.find("class");
	if (it != changed_attributes.end()) {
		SetClassName(it->second);
		Update();
	}

	it = changed_attributes.find("style");
	if (it != changed_attributes.end()) {
		PropertyVector properties;
		StyleSheetParser parser;
		parser.ParseProperties(properties, it->second);
		SetProperty(properties);
	}
	
	for (const auto& pair: changed_attributes) {
		if (pair.first.size() > 2 && pair.first[0] == 'o' && pair.first[1] == 'n') {
			EventListener* listener = GetPlugin()->OnCreateEventListener(this, pair.first.substr(2), pair.second, false);
			if (listener) {
				AddEventListener(listener);
			}
		}
	}
}

void Element::ChangedProperties(const PropertyIdSet& changed_properties) {
	const bool border_radius_changed = (
		changed_properties.contains(PropertyId::BorderTopLeftRadius) ||
		changed_properties.contains(PropertyId::BorderTopRightRadius) ||
		changed_properties.contains(PropertyId::BorderBottomRightRadius) ||
		changed_properties.contains(PropertyId::BorderBottomLeftRadius)
		);
	if (parent) {
		if (changed_properties.contains(PropertyId::Display)) {
			parent->DirtyStructure();
		}
		if (changed_properties.contains(PropertyId::ZIndex)) {
			parent->DirtyStackingContext();
		}
	}

	if (border_radius_changed ||
		changed_properties.contains(PropertyId::BackgroundColor) ||
		changed_properties.contains(PropertyId::BackgroundImage) ||
		changed_properties.contains(PropertyId::Opacity))
	{
		dirty.insert(Dirty::Background);
	}

	if (border_radius_changed ||
		changed_properties.contains(PropertyId::BorderTopWidth) ||
		changed_properties.contains(PropertyId::BorderRightWidth) ||
		changed_properties.contains(PropertyId::BorderBottomWidth) ||
		changed_properties.contains(PropertyId::BorderLeftWidth) ||
		changed_properties.contains(PropertyId::BorderTopColor) ||
		changed_properties.contains(PropertyId::BorderRightColor) ||
		changed_properties.contains(PropertyId::BorderBottomColor) ||
		changed_properties.contains(PropertyId::BorderLeftColor) ||
		changed_properties.contains(PropertyId::Opacity))
	{
		dirty.insert(Dirty::Background);
	}

	if (changed_properties.contains(PropertyId::OutlineWidth) ||
		changed_properties.contains(PropertyId::OutlineColor))
	{
		dirty.insert(Dirty::Background);
	}

	if (border_radius_changed ||
		changed_properties.contains(PropertyId::BackgroundImage) ||
		changed_properties.contains(PropertyId::BackgroundOrigin) ||
		changed_properties.contains(PropertyId::BackgroundSize) ||
		changed_properties.contains(PropertyId::BackgroundSizeX) ||
		changed_properties.contains(PropertyId::BackgroundSizeY) ||
		changed_properties.contains(PropertyId::BackgroundPositionX) ||
		changed_properties.contains(PropertyId::BackgroundPositionY) ||
		changed_properties.contains(PropertyId::BackgroundRepeat) ||
		changed_properties.contains(PropertyId::Opacity))
	{
		dirty.insert(Dirty::Image);
	}

	if (changed_properties.contains(PropertyId::Perspective) ||
		changed_properties.contains(PropertyId::PerspectiveOriginX) ||
		changed_properties.contains(PropertyId::PerspectiveOriginY))
	{
		DirtyPerspective();
	}

	if (changed_properties.contains(PropertyId::Transform) ||
		changed_properties.contains(PropertyId::TransformOriginX) ||
		changed_properties.contains(PropertyId::TransformOriginY) ||
		changed_properties.contains(PropertyId::TransformOriginZ))
	{
		DirtyTransform();
		if (clip.type != Clip::Type::None) {
			DirtyClip();
		}
	}

	if (changed_properties.contains(PropertyId::ScrollLeft) ||
		changed_properties.contains(PropertyId::ScrollTop))
	{
		for (auto& child : children) {
			child->DirtyTransform();
		}
	}

	if (changed_properties.contains(PropertyId::Overflow)) {
		DirtyClip();
	}

	if (changed_properties.contains(PropertyId::Animation)) {
		dirty.insert(Dirty::Animation);
	}

	if (changed_properties.contains(PropertyId::Transition)) {
		dirty.insert(Dirty::Transition);
	}

	for (auto& child : childnodes) {
		if (child->GetType() == Layout::Type::Text) {
			auto text = static_cast<Text*>(child.get());
			text->ChangedProperties(changed_properties);
		}
	}
}

std::string Element::GetInnerHTML() const {
	std::string html;
	for (auto& child : childnodes) {
		html += child->GetOuterHTML();
	}
	return html;
}

std::string Element::GetOuterHTML() const {
	std::string html;
	html += "<";
	html += tag;
	for (auto& pair : attributes) {
		auto& name = pair.first;
		auto& value = pair.second;
		html += " " + name + "=\"" + value + "\"";
	}
	if (!childnodes.empty()) {
		html += ">";
		html += GetInnerHTML();
		html += "</";
		html += tag;
		html += ">";
	}
	else {
		html += " />";
	}
	return html;
}

void Element::UpdateDataModel() {
	if (!IsVisible()) {
		return;
	}
	if (!GetOwnerDocument()->HasDataModel()) {
		return;
	}
	if (!dirty.contains(Dirty::DataModel)) {
		for (auto& child : childnodes) {
			child->UpdateDataModel();
		}
		return;
	}
	dirty.erase(Dirty::DataModel);
	auto it = attributes.find("data-for");
	if (it != attributes.end()) {
		SetVisible(false);
		UpdateLayout();
		DataModelLoad(it->first, it->second);
	}
	else {
		for (auto const& [name, value] : attributes) {
			constexpr size_t data_str_length = sizeof("data-") - 1;
			if (name.size() > data_str_length && name[0] == 'd' && name[1] == 'a' && name[2] == 't' && name[3] == 'a' && name[4] == '-') {
				DataModelLoad(name, value);
			}
		}
		for (auto& child : childnodes) {
			child->UpdateDataModel();
		}
	}
}


void Element::DataModelLoad(const std::string& name, const std::string& value) {
	GetPlugin()->OnDataModelLoad(GetOwnerDocument(), this, name, value);
}

void Element::RefreshProperties() {
	auto& c = Style::Instance();
	c.Release(global_properties);
	if (parent) {
		DirtyDefinition();
		DirtyInheritableProperties();
		global_properties = c.Inherit(local_properties, parent->global_properties);
	}
	else {
		global_properties = c.Inherit(local_properties);
	}
	for (auto& child : children) {
		child->RefreshProperties();
	}
}

void Element::SetParentNode(Element* _parent) {
	parent = _parent;

	RefreshProperties();
	DirtyTransform();
	DirtyClip();
	DirtyPerspective();
	DirtyDataModel();
}

void Element::UpdateStackingContext() {
	if (!dirty.contains(Dirty::StackingContext)) {
		return;
	}
	dirty.erase(Dirty::StackingContext);
	stacking_context.clear();
	stacking_context.reserve(childnodes.size());
	for (auto& child : childnodes) {
		stacking_context.push_back(child.get());
	}
	std::stable_sort(stacking_context.begin(), stacking_context.end(),
		[](auto&& lhs, auto&& rhs) {
			return lhs->GetZIndex() < rhs->GetZIndex();
		}
	);
}

void Element::DirtyStackingContext() {
	dirty.insert(Dirty::StackingContext);
}

void Element::DirtyStructure() {
	dirty.insert(Dirty::Structure);
}

void Element::DirtyDataModel() {
	dirty.insert(Dirty::DataModel);
	for (auto& child : childnodes) {
		child->DirtyDataModel();
	}
}

void Element::UpdateStructure() {
	if (dirty.contains(Dirty::Structure)) {
		dirty.erase(Dirty::Structure);
		DirtyDefinition();
	}
}

void Element::StartTransition(std::function<void()> f) {
	auto transition_list = GetComputedProperty(PropertyId::Transition)->Get<TransitionList>();
	if (transition_list.empty()) {
		f();
		return;
	}
	struct PropertyTransition {
		PropertyId              id;
		const Transition&       transition;
		std::optional<Property> start_value;
		PropertyTransition(PropertyId id, const Transition& transition, std::optional<Property> start_value)
			: id(id)
			, transition(transition)
			, start_value(start_value)
		{}
	};
	std::vector<PropertyTransition> pt;
	pt.reserve(transition_list.size());
	for (auto const& [id, transition] : transition_list) {
		auto start_value = GetComputedProperty(id);
		pt.emplace_back(id, transition, start_value);
	}
	f();
	for (auto& [id, transition, start_value] : pt) {
		auto target_value = GetComputedProperty(id);
		if (start_value && target_value && *start_value != *target_value) {
			if (!transitions.contains(id)) {
				ElementTransition ani {*start_value, *target_value, transition };
				if (ani.IsValid(*this)) {
					SetAnimationProperty(id, *start_value);
					transitions.insert_or_assign(id, std::move(ani));
				}
			}
		}
	}
}

void Element::HandleTransitionProperty() {
	if (!dirty.contains(Dirty::Transition)) {
		return;
	}
	dirty.erase(Dirty::Transition);

	auto keep = GetComputedProperty(PropertyId::Transition)->Get<TransitionList>();
	if (keep.empty()) {
		for (auto& [id, _] : transitions) {
			DelAnimationProperty(id);
		}
		transitions.clear();
	}
	else {
		for (auto it = transitions.begin(); it != transitions.end();) {
			if (keep.find(it->first) == keep.end()) {
				DelAnimationProperty(it->first);
				it = transitions.erase(it);
			}
			else {
				++it;
			}
		}
	}
}

void Element::HandleAnimationProperty() {
	if (!dirty.contains(Dirty::Animation)) {
		return;
	}
	dirty.erase(Dirty::Animation);

	for (auto& [id, _] : animations) {
		DelAnimationProperty(id);
	}
	animations.clear();

	auto property = GetComputedProperty(PropertyId::Animation);
	if (!property) {
		return;
	}
	const AnimationList& animation_list = property->Get<AnimationList>();
	bool element_has_animations = (!animation_list.empty() || !animations.empty());

	if (!element_has_animations) {
		return;
	}

	const StyleSheet& stylesheet = GetStyleSheet();

	for (const auto& animation : animation_list) {
		if (const Keyframes* keyframes_ptr = stylesheet.GetKeyframes(animation.name)) {
			auto& properties = keyframes_ptr->properties;
			if (keyframes_ptr->properties.size() >= 1 && !animation.paused) {
				for (auto const& [id, vec] : properties) {
					bool has_from_key = (vec[0].time == 0);
					bool has_to_key = (vec.back().time == 1);
					std::optional<Property> start_value;
					std::optional<Property> target_value;
					if (has_from_key) {
						start_value = vec[0].prop;
					}
					else {
						start_value = GetComputedProperty(id);
					}
					if (has_to_key) {
						target_value = vec.back().prop;
					}
					else {
						target_value = GetComputedProperty(id);
					}
					if (!start_value || !target_value) {
						continue;
					}
					ElementAnimation ani { *start_value, *target_value, animation };
					for (int i = (has_from_key ? 1 : 0); i < (int)vec.size() + (has_to_key ? -1 : 0); i++) {
						ani.AddKey(vec[i].time, vec[i].prop);
					}
					DispatchAnimationEvent("animationstart", ani);
					animations.insert_or_assign(id, std::move(ani));
				}
			}
		}
	}
}

void Element::AdvanceAnimations(float delta) {
	if (!animations.empty()) {
		for (auto& [id, e] : animations) {
			e.Update(*this, id, delta);
		}
		for (auto it = animations.begin(); it != animations.end();) {
			if (it->second.IsComplete()) {
				//TODO animationcancel
				DispatchAnimationEvent("animationend", it->second);
				DelAnimationProperty(it->first);
				it = animations.erase(it);
			}
			else {
				++it;
			}
		}
	}
	if (!transitions.empty()) {
		for (auto& [id, e] : transitions) {
			e.Update(*this, id, delta);
		}
		for (auto it = transitions.begin(); it != transitions.end();) {
			if (it->second.IsComplete()) {
				DelAnimationProperty(it->first);
				it = transitions.erase(it);
			}
			else {
				++it;
			}
		}
	}
	UpdateProperties();
}

void Element::DirtyPerspective() {
	dirty.insert(Dirty::Perspective);
}

void Element::UpdateTransform() {
	if (!dirty.contains(Dirty::Transform))
		return;
	dirty.erase(Dirty::Transform);
	glm::mat4x4 new_transform(1);
	Point origin2d = GetBounds().origin;
	if (parent) {
		origin2d = origin2d - parent->GetScrollOffset();
	}
	glm::vec3 origin(origin2d.x, origin2d.y, 0);
	auto computedTransform = GetComputedProperty(PropertyId::Transform)->Get<Transform>();
	if (!computedTransform.empty()) {
		glm::vec3 transform_origin = origin + glm::vec3 {
			ComputeOrigin(GetComputedProperty(PropertyId::TransformOriginX)).ComputeW(this),
			ComputeOrigin(GetComputedProperty(PropertyId::TransformOriginY)).ComputeH(this),
			ComputeOrigin(GetComputedProperty(PropertyId::TransformOriginZ)).Compute (this),
		};
		new_transform = glm::translate(transform_origin) * computedTransform.GetMatrix(*this) * glm::translate(-transform_origin);
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
	if (!dirty.contains(Dirty::Perspective))
		return;
	dirty.erase(Dirty::Perspective);
	auto p = GetComputedProperty(PropertyId::Perspective);
	if (!p->Has<PropertyFloat>()) {
		return;
	}
	float distance = p->Get<PropertyFloat>().Compute(this);
	bool changed = false;
	if (distance > 0.0f) {
		glm::vec3 origin = PerspectiveOrigin(this);
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
	if (dirty.contains(Dirty::Background)) {
		if (!geometry_background) {
			geometry_background.reset(new Geometry);
		}
		else {
			geometry_background->Release();
		}
		ElementBackgroundBorder::GenerateGeometry(this, *geometry_background, padding_edge);
		dirty.erase(Dirty::Background);
		dirty.insert(Dirty::Image);
	}
	if (dirty.contains(Dirty::Image)) {
		if (!geometry_image) {
			geometry_image.reset(new Geometry);
		}
		else {
			geometry_image->Release();
		}
		if (!ElementBackgroundImage::GenerateGeometry(this, *geometry_image, padding_edge)) {
			geometry_image.reset();
		}
		dirty.erase(Dirty::Image);
	}
}

void Element::UpdateRender() {
	UpdateTransform();
	UpdatePerspective();
	UpdateClip();
	for (auto& child : children) {
		child->UpdateRender();
	}
}

void Element::CalculateLayout() {
	padding = GetLayout().GetPadding();
	border = GetLayout().GetBorder();
	DirtyTransform();
	DirtyClip();
	dirty.insert(Dirty::Background);
	dirty.insert(Dirty::Image);
	Rect content {};
	for (auto& child : childnodes) {
		child->UpdateLayout();
		if (child->IsVisible()) {
			content.Union(child->GetContentRect());
		}
	}
	content_rect = GetBounds();
	content_rect.Union(content);
}

Element* Element::ElementFromPoint(Point point) {
	if (!IsVisible()) {
		return nullptr;
	}
	bool childVisible = clip.type != Clip::Type::Scissor || Rect{ (float)clip.scissor.x, (float)clip.scissor.y, (float)clip.scissor.z, (float)clip.scissor.w }.Contains(point);
	if (childVisible) {
		if (auto res = ChildFromPoint(point)) {
			return res;
		}
	}
	if (!IgnorePointerEvents() && Project(point) && Rect { {}, GetBounds().size }.Contains(point)) {
		return this;
	}
	return nullptr;
}

Element* Element::ChildFromPoint(Point point) {
	UpdateStackingContext();
	for (auto iter = stacking_context.rbegin(); iter != stacking_context.rend() && (*iter)->GetZIndex() >= 0; ++iter) {
		Element* res = (*iter)->ElementFromPoint(point);
		if (res) {
			return res;
		}
	}
	return nullptr;
}

static glm::u16vec4 UnionScissor(const glm::u16vec4& a, glm::u16vec4& b) {
	auto x = std::max(a.x, b.x);
	auto y = std::max(a.y, b.y);
	auto mx = std::min(a.x+a.z, b.x+b.z);
	auto my = std::min(a.y+a.w, b.y+b.w);
	return {x, y, mx - x, my - y};
}

void Element::UnionClip(Clip& c) {
	switch (clip.type) {
	case Clip::Type::None:
		return;
	case Clip::Type::Shader:
		c = clip;
		return;
	case Clip::Type::Scissor:
		break;
	}
	switch (c.type) {
	case Clip::Type::None:
		c = clip;
		return;
	case Clip::Type::Shader:
		c = clip;
		return;
	case Clip::Type::Scissor:
		c.scissor = UnionScissor(c.scissor, clip.scissor);
		return;
	}
}

void Element::UpdateClip() {
	if (!dirty.contains(Dirty::Clip))
		return;
	dirty.erase(Dirty::Clip);
	for (auto& child : children) {
		child->DirtyClip();
	}

	if (GetLayout().GetOverflow() == Layout::Overflow::Visible) {
		clip.type = Clip::Type::None;
		if (parent) {
			parent->UnionClip(clip);
		}
		return;
	}
	Size size = GetBounds().size;
	if (size.IsEmpty()) {
		clip.type = Clip::Type::None;
		if (parent) {
			parent->UnionClip(clip);
		}
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
		clip.type = Clip::Type::Scissor;
		clip.scissor.x = (glm::u16)std::floor(corners[0].x);
		clip.scissor.y = (glm::u16)std::floor(corners[0].y);
		clip.scissor.z = (glm::u16)std::ceil(corners[2].x - clip.scissor.x);
		clip.scissor.w = (glm::u16)std::ceil(corners[2].y - clip.scissor.y);
	}
	else {
		clip.type = Clip::Type::Shader;
		clip.shader[0].x = corners[0].x; clip.shader[0].y = corners[0].y;
		clip.shader[0].z = corners[1].x; clip.shader[0].w = corners[1].y;
		clip.shader[1].z = corners[2].x; clip.shader[1].w = corners[2].y;
		clip.shader[1].x = corners[3].x; clip.shader[1].y = corners[3].y;
	}

	if (parent) {
		parent->UnionClip(clip);
	}
}

void Element::SetRenderStatus() {
	auto render = GetRenderInterface();
	render->SetTransform(transform);
	render->SetGray(IsGray());
	switch (clip.type) {
	case Clip::Type::None:    render->SetClipRect();             break;
	case Clip::Type::Scissor: render->SetClipRect(clip.scissor); break;
	case Clip::Type::Shader:  render->SetClipRect(clip.shader);  break;
	}
}

void Element::DirtyTransform() {
	dirty.insert(Dirty::Transform);
}

void Element::DirtyClip() {
	dirty.insert(Dirty::Clip);
}

void Element::DirtyImage() {
	dirty.insert(Dirty::Image);
}

void Element::AddEventListener(EventListener* listener) {
	listeners.emplace_back(listener);
}

void Element::RemoveEventListener(EventListener* listener) {
	auto it = std::find_if(listeners.begin(), listeners.end(), [&](auto const& a){
		return a.get() == listener;
	});
	if (it != listeners.end()) {
		listeners.erase(it);
	}
}

void Element::RemoveEventListener(const std::string& type) {
	listeners.erase(std::remove_if(listeners.begin(), listeners.end(), [&](auto const& a){
		return a->type == type;
	}), listeners.end());
}

void Element::RemoveAllEvents() {
	listeners.clear();
	for (auto& child : children) {
		child->RemoveAllEvents();
	}
}

bool Element::DispatchEvent(const std::string& type, int parameters_ref, bool interruptible, bool bubbles) {
	Event event(this, type, parameters_ref, interruptible);
	return Rml::DispatchEvent(event, bubbles);
}

bool Element::DispatchEvent(const std::string& type, const luavalue::table& parameters, bool interruptible, bool bubbles) {
	lua_State* L = luabind::thread();
	luavalue::get(L, parameters);
	auto ref = get_lua_plugin()->ref(L);
	return DispatchEvent(type, ref.handle(), interruptible, bubbles);
}

bool Element::DispatchAnimationEvent(const std::string& type, const ElementAnimation& animation) {
	return DispatchEvent(type, {
		{ "animationName", animation.GetName() },
		{ "elapsedTime", animation.GetTime() },
	}, true, true);
}

const std::vector<std::unique_ptr<EventListener>>& Element::GetEventListeners() const {
	return listeners;
}

Size Element::GetScrollOffset() const {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return {0,0};
	}
	return {
		GetComputedProperty(PropertyId::ScrollLeft)->Get<PropertyFloat>().Compute(this),
		GetComputedProperty(PropertyId::ScrollTop)->Get<PropertyFloat>().Compute(this)
	};
}

float Element::GetScrollLeft() const {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return 0;
	}
	return GetComputedProperty(PropertyId::ScrollLeft)->Get<PropertyFloat>().Compute(this);
}

float Element::GetScrollTop() const {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return 0;
	}
	return GetComputedProperty(PropertyId::ScrollTop)->Get<PropertyFloat>().Compute(this);
}

void Element::SetScrollLeft(float v) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	Size offset { v, 0 };
	UpdateScrollOffset(offset);
	Property value(offset.w, PropertyUnit::PX);
	SetProperty({{PropertyId::ScrollLeft, std::move(value)}});
}

void Element::SetScrollTop(float v) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	Size offset { 0, v };
	UpdateScrollOffset(offset);
	Property value(offset.h, PropertyUnit::PX);
	SetProperty({{PropertyId::ScrollTop, std::move(value)}});
}

void Element::SetScrollInsets(const EdgeInsets<float>& insets) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	scroll_insets = insets;
	Size offset = GetScrollOffset();
	UpdateScrollOffset(offset);

	Property left(offset.w, PropertyUnit::PX);
	SetProperty({{PropertyId::ScrollLeft, std::move(left)}});

	Property top(offset.h, PropertyUnit::PX);
	SetProperty({{PropertyId::ScrollTop, std::move(top)}});
}

template <typename T>
static void clamp(T& v, T min, T max) {
	assert(min <= max);
	if (v < min) {
		v = min;
	}
	else if (v > max) {
		v = max;
	}
}

static void clamp(Size& s, Rect r) {
	clamp(s.w, r.left(), r.right());
	clamp(s.h, r.top(), r.bottom());
}

void Element::UpdateScrollOffset(Size& scrollOffset) const {
	auto const& bounds = GetBounds();
	clamp(scrollOffset, content_rect + scroll_insets - EdgeInsets<float> {0, 0, bounds.size.w, bounds.size.h});
}

void Element::SetPseudoClass(PseudoClass pseudo_class, bool activate) {
	PseudoClassSet old = pseudo_classes;
	if (activate)
		pseudo_classes = pseudo_classes | pseudo_class;
	else
		pseudo_classes = pseudo_classes & ~pseudo_class;
	if (old != pseudo_classes) {
		DirtyDefinition();
	}
}

bool Element::IsPseudoClassSet(PseudoClassSet pseudo_class) const {
	return (pseudo_class & ~pseudo_classes) == 0;
}

PseudoClassSet Element::GetActivePseudoClasses() const {
	return pseudo_classes;
}

void Element::SetClass(const std::string& class_name, bool activate) {
	std::vector<std::string>::iterator class_location = std::find(classes.begin(), classes.end(), class_name);
	if (activate) {
		if (class_location == classes.end()) {
			classes.push_back(class_name);
			DirtyDefinition();
		}
	}
	else {
		if (class_location != classes.end()) {
			classes.erase(class_location);
			DirtyDefinition();
		}
	}
}

bool Element::IsClassSet(const std::string& class_name) const {
	return std::find(classes.begin(), classes.end(), class_name) != classes.end();
}

void Element::SetClassName(const std::string& class_names) {
	classes.clear();
	StringUtilities::ExpandString(classes, class_names, ' ');
	DirtyDefinition();
}

void Element::DirtyPropertiesWithUnitRecursive(PropertyUnit unit) {
	DirtyProperties(unit);
	for (auto& child : children) {
		child->DirtyPropertiesWithUnitRecursive(unit);
	}
}

std::optional<Property> Element::GetInlineProperty(PropertyId id) const {
	auto& c = Style::Instance();
	return c.Find(inline_properties, id);
}

std::optional<Property> Element::GetLocalProperty(PropertyId id) const {
	auto& c = Style::Instance();
    return c.Find(local_properties, id);
}

bool Element::SetProperty(const std::string& name, std::optional<std::string> value) {
	if (value) {
		PropertyVector properties;
		if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, *value)) {
			Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value->c_str());
			return false;
		}
		return SetProperty(properties);
	}
	else {
		PropertyIdSet properties;
		if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name)) {
			Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s;'.", name.c_str());
			return false;
		}
		return DelProperty(properties);
	}
}

std::optional<std::string> Element::GetProperty(const std::string& name) const {
	PropertyIdSet properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s;'.", name.c_str());
		return std::nullopt;
	}

	std::string res;
	for (const auto& property_id : properties) {
		auto property = GetInlineProperty(property_id);
		if (property) {
			if (!res.empty()) {
				res += " ";
			}
			res += property->ToString();
		}
	}
	return res;
}

std::optional<Property> Element::GetComputedProperty(PropertyId id) const {
	auto& c = Style::Instance();
	if (auto property = c.Find(global_properties, id)) {
		return property;
	}
	if (auto property = c.Find(StyleSheetSpecification::GetDefaultProperties(), id)) {
		return property;
	}
	return std::nullopt;
}

void Element::UpdateDefinition() {
	if (!dirty.contains(Dirty::Definition)) {
		return;
	}
	dirty.erase(Dirty::Definition);
	auto new_definition = GetStyleSheet().GetElementDefinition(this);
	auto& c = Style::Instance();
	PropertyIdSet changed_properties = c.Diff(definition_properties, new_definition);
	for (PropertyId id : changed_properties) {
		if (c.Has(inline_properties, id)) {
			changed_properties.erase(id);
		}
	}
	StartTransition([&](){
		c.Assgin(definition_properties, new_definition);
	});
	DirtyProperties(changed_properties);
	for (auto& child : children) {
		child->DirtyDefinition();
	}
}

bool Element::SetInlineProperty(const PropertyVector& vec) {
	auto change = Style::Instance().SetProperty(inline_properties, vec);
	if (!change.empty()) {
		DirtyProperties(change);
		return true;
	}
	return false;
}

bool Element::DelInlineProperty(const PropertyIdSet& set) {
	auto change = Style::Instance().DelProperty(inline_properties, set);
	if (!change.empty()) {
		DirtyProperties(change);
		return true;
	}
	return false;
}

bool Element::SetProperty(const PropertyVector& vec) {
	bool change;
	StartTransition([&](){
		change = SetInlineProperty(vec);
	});
	return change;
}

bool Element::DelProperty(const PropertyIdSet& set) {
	bool change;
	StartTransition([&](){
		change = DelInlineProperty(set);
	});
	return change;
}

void Element::SetAnimationProperty(PropertyId id, const Property& property) {
	if (Style::Instance().SetProperty(animation_properties, id, property)) {
		DirtyProperty(id);
	}
}

void Element::DelAnimationProperty(PropertyId id) {
	if (Style::Instance().DelProperty(animation_properties, id)) {
		DirtyProperty(id);
	}
}

void Element::DirtyDefinition() {
	dirty.insert(Dirty::Definition);
}

void Element::DirtyInheritableProperties() {
	dirty_properties |= StyleSheetSpecification::GetInheritableProperties();
}

void Element::DirtyProperties(PropertyUnit unit) {
	auto& c = Style::Instance();
	c.Foreach(local_properties, unit, dirty_properties);
}

void Element::DirtyProperty(PropertyId id) {
	dirty_properties.insert(id);
}

void Element::DirtyProperties(const PropertyIdSet& properties) {
	dirty_properties |= properties;
}

void Element::UpdateProperties() {
	if (dirty_properties.empty()) {
		return;
	}

	if (dirty_properties.contains(PropertyId::FontSize)) {
		if (UpdataFontSize()) {
			dirty_properties.insert(PropertyId::LineHeight);
			DirtyProperties(PropertyUnit::EM);
			if (GetOwnerDocument()->GetBody() == this) {
				DirtyPropertiesWithUnitRecursive(PropertyUnit::REM);
			}
		}
	}

	PropertyIdSet dirty_layout_properties = dirty_properties & LayoutProperties;
	for (PropertyId id : dirty_layout_properties) {
		if (auto property = GetLocalProperty(id)) {
			GetLayout().SetProperty(id, *property, this);
		}
	}

	PropertyIdSet dirty_inheritable_properties = (dirty_properties & StyleSheetSpecification::GetInheritableProperties());
	if (!dirty_inheritable_properties.empty()) {
		for (auto& child : children) {
			child->DirtyProperties(dirty_inheritable_properties);
		}
	}

	if (!dirty_properties.empty()) {
		ChangedProperties(dirty_properties);
		dirty_properties.clear();
	}
}

const Rect& Element::GetContentRect() const {
	return content_rect;
}

const EdgeInsets<float>& Element::GetPadding() const {
	return padding;
}

const EdgeInsets<float>& Element::GetBorder() const {
	return border;
}

bool Element::IsRemoved() const {
	return parent == nullptr && GetOwnerDocument()->GetBody() != this;
}

}
