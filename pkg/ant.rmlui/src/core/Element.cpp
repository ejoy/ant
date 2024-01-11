#include <core/Element.h>
#include <binding/Context.h>
#include <core/Document.h>
#include <core/ElementAnimation.h>
#include <core/ElementBackground.h>
#include <core/Event.h>
#include <util/HtmlParser.h>
#include <core/Interface.h>
#include <util/Log.h>
#include <util/StringUtilities.h>
#include <css/StyleSheetParser.h>
#include <css/StyleSheetSpecification.h>
#include <core/Text.h>
#include <core/Transform.h>
#include <util/AlwaysFalse.h>
#include <algorithm>
#include <cmath>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtx/transform.hpp>
#include <bee/nonstd/unreachable.h>

namespace Rml {

static float min4(float a, float b, float c, float d) {
	return std::min(std::min(a, b), std::min(c, d));
}

static float max4(float a, float b, float c, float d) {
	return std::max(std::max(a, b), std::max(c, d));
}

void ElementAabb::Set(const Rect& rect, const glm::mat4x4& transform) {
	glm::vec4 corners[] = {
		{ rect.left(),  rect.top(),    0, 1 },
		{ rect.right(), rect.top(),    0, 1 },
		{ rect.right(), rect.bottom(), 0, 1 },
		{ rect.left(),  rect.bottom(), 0, 1 },
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
		content.SetRect(corners[0].x, corners[0].y, corners[2].x - corners[0].x, corners[2].y - corners[0].y);
		normalize = true;
		return;
	}
	float l = min4(corners[0].x, corners[1].x, corners[2].x, corners[3].x);
	float t = min4(corners[0].y, corners[1].y, corners[2].y, corners[3].y);
	float r = max4(corners[0].x, corners[1].x, corners[2].x, corners[3].x);
	float b = max4(corners[0].y, corners[1].y, corners[2].y, corners[3].y);
	content.SetRect(l, t, r - l, b - t);
	normalize = false;
}

bool ElementClip::Test(const Rect& rect) const {
	switch (type) {
	case ElementClip::Type::None:
		return true;
	case ElementClip::Type::Any:
		return false;
	case ElementClip::Type::Scissor: {
		return true;
	}
	case ElementClip::Type::Shader: {
		return true;
	}
	default:
		std::unreachable();
	}
}

Element::Element(Document* owner, const std::string& tag)
	: LayoutNode(Layout::UseElement {})
	, tag(tag)
	, owner_document(owner)
{
	dirty.insert(Dirty::Definition);
	assert(owner);
}

Element::~Element() {
	assert(GetParentNode() == nullptr);
	assert(childnodes.empty());
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

	for (auto& child: children_under_render) {
		child->Render();
	}
	if (SetRenderStatus()) {
		geometry.Render();
		for (auto& child: children_upper_render) {
			child->Render();
		}
	}
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

	if (!include_parents) {
		return address;
	}
	if (auto parent = GetParentNode()) {
		address += " < ";
		return address + parent->GetAddress(include_pseudo_classes, true);
	}
	else {
		return address;
	}
}

bool Element::IgnorePointerEvents() const {
	return GetComputedProperty(PropertyId::PointerEvents).GetEnum<Style::PointerEvents>() == Style::PointerEvents::None;
}

float Element::GetZIndex() const {
	return GetComputedProperty(PropertyId::ZIndex).Get<PropertyFloat>().value;
}

float Element::GetFontSize() const {
	return font_size;
}

static float ComputeFontsize(const Property& prop, Element* element) {
	PropertyFloat fv = prop.Get<PropertyFloat>();
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
		new_size = ComputeFontsize(p, this);
	else if (auto parent = GetParentNode()) {
		new_size = parent->GetFontSize();
	}
	if (new_size != font_size) {
		font_size = new_size;
		return true;
	}
	return false;
}

bool Element::IsGray() {
	return GetComputedProperty(PropertyId::Filter).GetEnum<Style::Filter>() == Style::Filter::Gray;
}

float Element::GetOpacity() {
	auto property = GetComputedProperty(PropertyId::Opacity);
	return property.Get<PropertyFloat>().value;
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
	attributes[name] = value;
}

const std::string* Element::GetAttribute(const std::string& name) const {
	auto it = attributes.find(name);
	if (it == attributes.end()) {
		return nullptr;
	}
	return &it->second;
}

const ElementAttributes& Element::GetAttributes() const {
	return attributes;
}

void Element::RemoveAttribute(const std::string& name) {
	attributes.erase(name);
}

const std::string& Element::GetTagName() const {
	return tag;
}

const std::string& Element::GetId() const {
	return id;
}

void Element::SetId(const std::string& _id) {
	if (id != _id) {
		id = _id;
		DirtyDefinition();
	}
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
	HtmlElement dom;
	if (ParseHtml({}, html, true, dom)) {
		RemoveAllChildren();
		InstanceInner(dom);
	}
}

void Element::SetOuterHTML(const std::string& html) {
	if (html.empty()) {
		tag.clear();
		attributes.clear();
		RemoveAllChildren();
		return;
	}
	HtmlElement dom;
	if (ParseHtml({}, html, false, dom)) {
		RemoveAllChildren();
		InstanceOuter(dom);
		InstanceInner(dom);
	}
}

void Element::InstanceOuter(const HtmlElement& html) {
	tag = html.tag;
	attributes.clear();
	for (auto const& [name, value] : html.attributes) {
		if (name == "id") {
			SetId(value);
		}
		else if (name == "class") {
			SetClassName(value);
		}
		else if (name == "style") {
			PropertyVector properties;
			StyleSheetParser parser;
			parser.ParseProperties(value, properties);
			SetInlineProperty(properties);
		}
		else {
			attributes[name] = value;
		}
	}
}

void Element::InstanceInner(const HtmlElement& html) {
	for (auto const& node : html.children) {
		std::visit([this](auto&& arg) {
			using T = std::decay_t<decltype(arg)>;
			if constexpr (std::is_same_v<T, HtmlElement>) {
				Element* e = owner_document->CreateElement(arg.tag);
				if (e) {
					e->InstanceOuter(arg);
					e->NotifyCreated();
					e->InstanceInner(arg);
					AppendChild(e);
				}
			}
			else if constexpr (std::is_same_v<T, HtmlString>) {
				if (this->tag == "richtext") {
					RichText* e = owner_document->CreateRichTextNode(arg);
					if (e) {
						AppendChild(e);
					}
				}
				else {
					Text* e = owner_document->CreateTextNode(arg);
					if (e) {
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
		e->id = id;
		e->classes = classes;
		auto& c = Style::Instance();
		c.Clone(e->inline_properties, inline_properties);
		c.Foreach(e->inline_properties, e->dirty_properties);
		e->DirtyDefinition();
		for (auto const& [name, value] : attributes) {
			e->attributes[name] = value;
		}
		e->NotifyCreated();
		if (deep) {
			for (auto const& child : childnodes) {
				auto r = child->Clone(true);
				e->AppendChild(r);
			}
		}
	}
	return e;
}

void Element::NotifyCreated() {
	GetScript()->OnCreateElement(owner_document, this, GetTagName());
}

void Element::AppendChild(Node* node, size_t index) {
	Element* p = node->GetParentNode();
	if (p) {
		p->DetachChild(node).release();
	}
	if (index > childnodes.size()) {
		index = childnodes.size();
	}
	childnodes.emplace_back(node);
	switch (node->GetType()) {
	case Node::Type::Element: {
		auto e = static_cast<Element*>(node);
		LayoutNode::InsertChild(e, index);
		children.emplace_back(e);
		break;
	}
	case Node::Type::Text: {
		auto e = static_cast<Text*>(node);
		LayoutNode::InsertChild(e, index);
		break;
	}
	default:
		break;
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
	
	switch (node->GetType()) {
	case Node::Type::Element: {
		auto e = static_cast<Element*>(node);
		for (auto it = children.begin(); it != children.end(); ++it) {
			if (*it == e) {
				children.erase(it);
				break;
			}
		}
		LayoutNode::RemoveChild(e);
		break;
	}
	case Node::Type::Text: {
		auto e = static_cast<Text*>(node);
		LayoutNode::RemoveChild(e);
		break;
	}
	default:
		break;
	}
	node->ResetParentNode();
	DirtyStackingContext();
	DirtyStructure();
	return detached_child;
}

void Element::RemoveChild(Node* node) {
	auto detached_child = DetachChild(node);
	if (detached_child) {
		if (node->GetType() == Node::Type::Element) {
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
	childnodes.emplace(childnodes.begin() + index, node);
	switch (node->GetType()) {
	case Node::Type::Element: {
		auto e = static_cast<Element*>(node);
		LayoutNode::InsertChild(e, index);
		children.emplace_back(e);
		break;
	}
	case Node::Type::Text: {
		auto e = static_cast<Text*>(node);
		LayoutNode::InsertChild(e, index);
		break;
	}
	default:
		break;
	}
	node->SetParentNode(this);
	DirtyStackingContext();
	DirtyStructure();
}

Node* Element::GetPreviousSibling() {
	if (auto parent = GetParentNode()) {
		size_t index = parent->GetChildNodeIndex(this);
		if (index == size_t(-1)) {
			return nullptr;
		}
		if (index == 0) {
			return nullptr;
		}
		return parent->childnodes[index-1].get();
	}
	return nullptr;
}

void Element::RemoveAllChildren() {
	for (auto& child : children) {
		child->RemoveAllChildren();
	}
	for (auto&& child : childnodes) {
		child->ResetParentNode();
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

void Element::GetElementsByTagName(const std::string& tag, std::function<void(Element*)> func) {
	if (GetTagName() == tag) {
		func(this);
	}
	for (auto& child : children) {
		child->GetElementsByTagName(tag, func);
	}
}

void Element::GetElementsByClassName(const std::string& class_name, std::function<void(Element*)> func) {
	if (IsClassSet(class_name)) {
		func(this);
	}
	for (auto& child : children) {
		child->GetElementsByClassName(class_name, func);
	}
}

void Element::ChangedProperties(const PropertyIdSet& changed_properties) {
	const bool border_radius_changed = (
		changed_properties.contains(PropertyId::BorderTopLeftRadius) ||
		changed_properties.contains(PropertyId::BorderTopRightRadius) ||
		changed_properties.contains(PropertyId::BorderBottomRightRadius) ||
		changed_properties.contains(PropertyId::BorderBottomLeftRadius)
		);
	if (auto parent = GetParentNode()) {
		if (changed_properties.contains(PropertyId::Display)) {
			parent->DirtyStructure();
		}
		if (changed_properties.contains(PropertyId::ZIndex)) {
			parent->DirtyStackingContext();
		}
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
		changed_properties.contains(PropertyId::OutlineWidth) ||
		changed_properties.contains(PropertyId::OutlineColor) ||
		changed_properties.contains(PropertyId::BackgroundColor) ||
		changed_properties.contains(PropertyId::BackgroundImage) ||
		changed_properties.contains(PropertyId::BackgroundOrigin) ||
		changed_properties.contains(PropertyId::BackgroundSize) ||
		changed_properties.contains(PropertyId::BackgroundSizeX) ||
		changed_properties.contains(PropertyId::BackgroundSizeY) ||
		changed_properties.contains(PropertyId::BackgroundPositionX) ||
		changed_properties.contains(PropertyId::BackgroundPositionY) ||
		changed_properties.contains(PropertyId::BackgroundRepeat) ||
		changed_properties.contains(PropertyId::BackgroundFilter) ||
		changed_properties.contains(PropertyId::Opacity) ||
		changed_properties.contains(PropertyId::Filter))
	{
		dirty.insert(Dirty::Background);
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
		if (clip.type != ElementClip::Type::None && clip.type != ElementClip::Type::Any) {
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
		if (child->GetType() == Node::Type::Text) {
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

void Element::RefreshProperties() {
	auto& c = Style::Instance();
	if (auto parent = GetParentNode()) {
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
	Node::SetParentNode(_parent);

	RefreshProperties();
	DirtyTransform();
	DirtyClip();
	DirtyPerspective();
}

void Element::UpdateStackingContext() {
	if (!dirty.contains(Dirty::StackingContext)) {
		return;
	}
	dirty.erase(Dirty::StackingContext);
	children_under_render.clear();
	children_upper_render.clear();
	for (auto& child : childnodes) {
		switch (child->GetType()) {
		case Node::Type::Element:
		case Node::Type::Text: {
			auto node = static_cast<LayoutNode*>(child.get());
			if (node->GetZIndex() < 0) {
				children_under_render.push_back(node);
			}
			else {
				children_upper_render.push_back(node);
			}
			break;
		}
		case Node::Type::Comment:
			break;
		}
	}
	std::stable_sort(children_under_render.begin(), children_under_render.end(),
		[](auto&& lhs, auto&& rhs) {
			return lhs->GetZIndex() < rhs->GetZIndex();
		}
	);
	std::stable_sort(children_upper_render.begin(), children_upper_render.end(),
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

void Element::UpdateStructure() {
	if (dirty.contains(Dirty::Structure)) {
		dirty.erase(Dirty::Structure);
		DirtyDefinition();
	}
}

void Element::StartTransition(std::function<void()> f) {
	auto transition_list = GetComputedProperty(PropertyId::Transition).Get<TransitionList>();
	if (transition_list.empty()) {
		f();
		return;
	}
	struct PropertyTransition {
		PropertyId        id;
		const Transition& transition;
		Property      start_value;
		PropertyTransition(PropertyId id, const Transition& transition, Property start_value)
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
		if (start_value && target_value && start_value != target_value) {
			if (!transitions.contains(id)) {
				SetAnimationProperty(id, start_value);
				transitions.emplace(id, ElementTransition { *this, id, transition, start_value, target_value });
			}
		}
	}
}

void Element::HandleTransitionProperty() {
	if (!dirty.contains(Dirty::Transition)) {
		return;
	}
	dirty.erase(Dirty::Transition);

	auto keep = GetComputedProperty(PropertyId::Transition).Get<TransitionList>();
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
	const AnimationList& animation_list = property.Get<AnimationList>();
	bool element_has_animations = (!animation_list.empty() || !animations.empty());

	if (!element_has_animations) {
		return;
	}

	const StyleSheet& stylesheet = GetOwnerDocument()->GetStyleSheet();

	for (const auto& animation : animation_list) {
		if (!animation.paused) {
			if (const Keyframes* keyframes = stylesheet.GetKeyframes(animation.name)) {
				for (auto const& [id, keyframe] : *keyframes) {
					auto [res, suc] = animations.emplace(id, ElementAnimation { *this, id, animation, keyframe });
					if (suc) {
						DispatchAnimationEvent("animationstart", res->second);
					}
				}
			}
		}
	}
}

void Element::AdvanceAnimations(float delta) {
	if (!animations.empty()) {
		for (auto& [id, animation] : animations) {
			if (!animation.IsComplete() && delta > 0.0f) {
				auto p2 = animation.UpdateProperty(*this, delta);
				SetAnimationProperty(id, p2);
			}
		}
		for (auto it = animations.begin(); it != animations.end();) {
			auto& id = it->first;
			auto& animation = it->second;
			if (animation.IsComplete()) {
				//TODO animationcancel
				DispatchAnimationEvent("animationend", animation);
				DelAnimationProperty(id);
				it = animations.erase(it);
			}
			else {
				++it;
			}
		}
	}
	if (!transitions.empty()) {
		for (auto& [id, transition] : transitions) {
			if (!transition.IsComplete() && delta > 0.0f) {
				auto p2 = transition.UpdateProperty(delta);
				SetAnimationProperty(id, p2);
			}
		}
		for (auto it = transitions.begin(); it != transitions.end();) {
			auto& id = it->first;
			auto& transition = it->second;
			if (transition.IsComplete()) {
				DelAnimationProperty(id);
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
	if (auto parent = GetParentNode()) {
		origin2d = origin2d - parent->GetScrollOffset();
	}
	glm::vec3 origin(origin2d.x, origin2d.y, 0);
	auto computedTransform = GetComputedProperty(PropertyId::Transform).Get<Transform>();
	if (!computedTransform.empty()) {
		glm::vec3 transform_origin = origin + glm::vec3 {
			PropertyComputeX(this, GetComputedProperty(PropertyId::TransformOriginX)),
			PropertyComputeY(this, GetComputedProperty(PropertyId::TransformOriginY)),
			PropertyComputeZ(this, GetComputedProperty(PropertyId::TransformOriginZ))
		};
		new_transform = glm::translate(transform_origin) * computedTransform.GetMatrix(*this) * glm::translate(-transform_origin);
	}
	new_transform = glm::translate(new_transform, origin);
	if (auto parent = GetParentNode()) {
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
	aabb.Set(Rect { {}, GetBounds().size }, transform);
}

void Element::UpdatePerspective() {
	if (!dirty.contains(Dirty::Perspective))
		return;
	dirty.erase(Dirty::Perspective);
	auto p = GetComputedProperty(PropertyId::Perspective);
	if (!p.Has<PropertyFloat>()) {
		return;
	}
	float distance = p.Get<PropertyFloat>().Compute(this);
	bool changed = false;
	if (distance > 0.0f) {
		auto originX = GetComputedProperty(PropertyId::PerspectiveOriginX);
		auto originY = GetComputedProperty(PropertyId::PerspectiveOriginY);
		float x = PropertyComputeX(this, originX);
		float y = PropertyComputeY(this, originY);
		glm::vec3 origin = { x, y, 0.f };
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
		dirty.erase(Dirty::Background);
		geometry.Update(this);
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
	Rect content {};
	for (auto& child : childnodes) {
		if (child->UpdateLayout()) {
			content.Union(child->GetContentRect());
		}
	}
	content_rect = GetBounds();
	content_rect.Union(content);
}

static float checkSign(glm::vec2 a, glm::vec2 b, glm::vec2 p) {
	glm::vec2 ab = b - a;
	glm::vec2 ap = p - a;
	return ab.x * ap.y - ab.y * ap.x;
}

static bool InClip(ElementClip& clip, Point point) {
	switch (clip.type) {
	case ElementClip::Type::None:
		return true;
	case ElementClip::Type::Any:
		return false;
	case ElementClip::Type::Shader: {
		glm::vec2 lt { clip.shader[0].x, clip.shader[0].y };
		glm::vec2 rt { clip.shader[0].z, clip.shader[0].w };
		glm::vec2 lb { clip.shader[1].x, clip.shader[1].y };
		glm::vec2 rb { clip.shader[1].z, clip.shader[1].w };
		glm::vec2 p  { point.x, point.y };
		float sign1 = checkSign(lt, rt, p);
		float sign2 = checkSign(rt, rb, p);
		float sign3 = checkSign(rb, lb, p);
		float sign4 = checkSign(lb, lt, p);
		if (sign1 < 0 && sign2 < 0 && sign3 < 0 && sign4 < 0) {
			return true;
		}
		if (sign1 > 0 && sign2 > 0 && sign3 > 0 && sign4 > 0) {
			return true;
		}
		if (sign1 == 0 || sign2 == 0 || sign3 == 0 || sign4 == 0) {
			return true;
		}
		return false;
	}
	case ElementClip::Type::Scissor:
		return Rect { (float)clip.scissor.x, (float)clip.scissor.y, (float)clip.scissor.z, (float)clip.scissor.w }.Contains(point);
	default:
		std::unreachable();
	}
}

Element* Element::ElementFromPoint(Point point) {
	if (!IsVisible()) {
		return nullptr;
	}
	if (InClip(clip, point)) {
		UpdateStackingContext();
		for (auto iter = children_upper_render.rbegin(); iter != children_upper_render.rend(); ++iter) {
			Element* res = (*iter)->ElementFromPoint(point);
			if (res) {
				return res;
			}
		}
	}
	if (aabb.content.Contains(point)) {
		if (!IgnorePointerEvents()) {
			if (aabb.normalize) {
				return this;
			}
			if (Project(point)) {
				if (Rect { {}, GetBounds().size }.Contains(point)) {
					return this;
				}
			}
		}
	}
	return nullptr;
}

template <typename V, typename T>
static T clamp(V v, T min, T max) {
	assert(min <= max);
	if (v < (V)min) {
		return min;
	}
	else if (v > (V)max) {
		return max;
	}
	return (T)v;
}

static glm::u16vec4 UnionScissor(const glm::u16vec4& a, glm::u16vec4& b) {
	auto x = std::max(a.x, b.x);
	auto y = std::max(a.y, b.y);
	auto mx = std::min(a.x+a.z, b.x+b.z);
	auto my = std::min(a.y+a.w, b.y+b.w);
	return {x, y, mx - x, my - y};
}

void Element::UnionClip(ElementClip& c) {
	switch (clip.type) {
	case ElementClip::Type::None:
		return;
	case ElementClip::Type::Any:
		c.type = ElementClip::Type::Any;
		return;
	case ElementClip::Type::Shader:
		c = clip;
		return;
	case ElementClip::Type::Scissor:
		break;
	default:
		std::unreachable();
	}
	switch (c.type) {
	case ElementClip::Type::None:
		c = clip;
		return;
	case ElementClip::Type::Any:
		return;
	case ElementClip::Type::Shader:
		c = clip;
		return;
	case ElementClip::Type::Scissor:
		c.scissor = UnionScissor(c.scissor, clip.scissor);
		return;
	default:
		std::unreachable();
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
		clip.type = ElementClip::Type::None;
		if (auto parent = GetParentNode()) {
			parent->UnionClip(clip);
		}
		return;
	}
	Size size = GetBounds().size;
	if (size.IsEmpty()) {
		clip.type = ElementClip::Type::Any;
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
		clip.type = ElementClip::Type::Scissor;
		clip.scissor.x = clamp(std::floor(corners[0].x)                , (glm::u16)0, std::numeric_limits<glm::u16>::max());
		clip.scissor.y = clamp(std::floor(corners[0].y)                , (glm::u16)0, std::numeric_limits<glm::u16>::max());
		clip.scissor.z = clamp(std::ceil(corners[2].x - clip.scissor.x), (glm::u16)0, std::numeric_limits<glm::u16>::max());
		clip.scissor.w = clamp(std::ceil(corners[2].y - clip.scissor.y), (glm::u16)0, std::numeric_limits<glm::u16>::max());
	}
	else {
		clip.type = ElementClip::Type::Shader;
		clip.shader[0].x = corners[0].x; clip.shader[0].y = corners[0].y;
		clip.shader[0].z = corners[1].x; clip.shader[0].w = corners[1].y;
		clip.shader[1].z = corners[2].x; clip.shader[1].w = corners[2].y;
		clip.shader[1].x = corners[3].x; clip.shader[1].y = corners[3].y;
	}

	if (auto parent = GetParentNode()) {
		parent->UnionClip(clip);
	}
}

bool Element::SetRenderStatus() {
	if (!clip.Test(aabb.content)) {
		return false;
	}
	auto render = GetRender();
	render->SetTransform(transform);
	switch (clip.type) {
	case ElementClip::Type::None:
		render->SetClipRect();
		break;
	case ElementClip::Type::Scissor:
		render->SetClipRect(clip.scissor);
		break;
	case ElementClip::Type::Shader:
		render->SetClipRect(clip.shader);
		break;
	default:
		std::unreachable();
	}
	return true;
}

void Element::DirtyTransform() {
	dirty.insert(Dirty::Transform);
}

void Element::DirtyClip() {
	dirty.insert(Dirty::Clip);
}

void Element::DirtyBackground() {
	dirty.insert(Dirty::Background);
}

bool Element::DispatchAnimationEvent(const std::string& type, const ElementAnimation& animation) {
	GetScript()->OnDispatchEvent(GetOwnerDocument(), this, type, {
		{ "animationName", animation.GetName() },
		{ "elapsedTime", animation.GetTime() },
	});
	return true;
}

Size Element::GetScrollOffset() const {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return {0,0};
	}
	return {
		GetComputedProperty(PropertyId::ScrollLeft).Get<PropertyFloat>().Compute(this),
		GetComputedProperty(PropertyId::ScrollTop).Get<PropertyFloat>().Compute(this)
	};
}

float Element::GetScrollLeft() const {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return 0;
	}
	return GetComputedProperty(PropertyId::ScrollLeft).Get<PropertyFloat>().Compute(this);
}

float Element::GetScrollTop() const {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return 0;
	}
	return GetComputedProperty(PropertyId::ScrollTop).Get<PropertyFloat>().Compute(this);
}

void Element::SetScrollLeft(float v) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	Size offset { v, 0 };
	UpdateScrollOffset(offset);
	StartTransition([&](){
		Property left = { PropertyId::ScrollLeft, PropertyFloat { offset.w, PropertyUnit::PX } };
		SetInlineProperty({ left });
	});
}

void Element::SetScrollTop(float v) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	Size offset { 0, v };
	UpdateScrollOffset(offset);
	StartTransition([&](){
		Property top = { PropertyId::ScrollTop, PropertyFloat { offset.h, PropertyUnit::PX } };
		SetInlineProperty({ top });
	});
}

void Element::SetScrollInsets(const EdgeInsets<float>& insets) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	scroll_insets = insets;
	Size offset = GetScrollOffset();
	UpdateScrollOffset(offset);

	StartTransition([&](){
		Property left = { PropertyId::ScrollLeft, PropertyFloat { offset.w, PropertyUnit::PX } };
		Property top = { PropertyId::ScrollTop, PropertyFloat { offset.h, PropertyUnit::PX } };
		SetInlineProperty({ left, top });
	});
}

void Element::UpdateScrollOffset(Size& scrollOffset) const {
	auto const& bounds = GetBounds();
	Rect r = content_rect + scroll_insets - EdgeInsets<float> {0, 0, bounds.size.w, bounds.size.h};
	scrollOffset.w = clamp(scrollOffset.w, r.left(), r.right());
	scrollOffset.h = clamp(scrollOffset.h, r.top(), r.bottom());
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

bool Element::IsClassSet(const std::string& class_name) const {
	return std::find(classes.begin(), classes.end(), class_name) != classes.end();
}

void Element::SetClassName(const std::string& class_names) {
	classes.clear();
	StringUtilities::ExpandString(classes, class_names, ' ');
	DirtyDefinition();
}

std::string Element::GetClassName() const {
	std::string res;
	for (auto& c : classes) {
		if (!res.empty()) {
			res += " ";
		}
		res += c;
	}
	return res;
}

void Element::DirtyPropertiesWithUnitRecursive(PropertyUnit unit) {
	DirtyProperties(unit);
	for (auto& child : children) {
		child->DirtyPropertiesWithUnitRecursive(unit);
	}
}

Property Element::GetInlineProperty(PropertyId id) const {
	auto& c = Style::Instance();
	if (auto prop = c.Find(inline_properties, id)) {
		return prop;
	}
	return {};
}

Property Element::GetLocalProperty(PropertyId id) const {
	auto& c = Style::Instance();
	if (auto prop = c.Find(local_properties, id)) {
		return prop;
	}
	return {};
}

bool Element::SetProperty(std::string_view name, std::string_view value) {
	bool changed;
	PropertyVector properties;
	if (!StyleSheetSpecification::ParseDeclaration(properties, name, value)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s: %s;'.", name.data(), value.data());
		return false;
	}
	StartTransition([&](){
		changed = SetInlineProperty(properties);
	});
	return changed;
}

bool Element::DelProperty(std::string_view name) {
	bool changed;
	PropertyIdSet properties;
	if (!StyleSheetSpecification::ParseDeclaration(properties, name)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s;'.", name.data());
		return false;
	}
	StartTransition([&](){
		changed = DelInlineProperty(properties);
	});
	return changed;
}

std::optional<std::string> Element::GetProperty(std::string_view name) const {
	PropertyIdSet properties;
	if (!StyleSheetSpecification::ParseDeclaration(properties, name)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s;'.", name.data());
		return std::nullopt;
	}

	std::string res;
	for (const auto& property_id : properties) {
		auto property = GetInlineProperty(property_id);
		if (property) {
			if (!res.empty()) {
				res += " ";
			}
			res += property.ToString();
		}
	}
	return res;
}

Property Element::GetComputedProperty(PropertyId id) const {
	auto& c = Style::Instance();
	if (auto prop = c.Find(global_properties, id)) {
		return prop;
	}
	if (auto prop = c.Find(StyleSheetSpecification::GetDefaultProperties(), id)) {
		return prop;
	}
	return {};
}

void Element::UpdateDefinition() {
	if (!dirty.contains(Dirty::Definition)) {
		return;
	}
	dirty.erase(Dirty::Definition);
	auto new_definition = GetOwnerDocument()->GetStyleSheet().GetElementDefinition(this);
	auto& c = Style::Instance();
	if (!c.Compare(definition_properties, new_definition)) {
		return;
	}
	PropertyIdSet changed_properties = c.Diff(definition_properties, new_definition);
	if (changed_properties.empty()) {
		return;
	}
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
			GetLayout().SetProperty(id, property, this);
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
	return GetParentNode() == nullptr && GetOwnerDocument()->GetBody() != this;
}

}
