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
#include <core/PropertyDefinition.h>
#include <core/Stream.h>
#include <core/StringUtilities.h>
#include <core/StyleSheetFactory.h>
#include <core/StyleSheetNode.h>
#include <core/StyleSheetParser.h>
#include <core/StyleSheetSpecification.h>
#include <core/Text.h>
#include <core/Transform.h>
#include <databinding/DataModel.h>
#include <databinding/DataUtilities.h>
#include <algorithm>
#include <cmath>
#include <yoga/YGNode.h>
#include <glm/gtc/matrix_transform.hpp>
#include <glm/gtx/transform.hpp>

namespace Rml {

static const Property* PropertyDictionaryGet(const PropertyDictionary& dict, PropertyId id) {
	auto iterator = dict.find(id);
	if (iterator == dict.end()) {
		return nullptr;
	}
	return &(*iterator).second;
}

static PropertyIdSet PropertyDictionaryGetIds(const PropertyDictionary& dict) {
	PropertyIdSet ids;
	for (auto& [id, _] : dict) {
		ids.insert(id);
	}
	return ids;
}

static PropertyIdSet PropertyDictionaryDiff(const PropertyDictionary& dict0, const PropertyDictionary& dict1) {
	PropertyIdSet mark;
	PropertyIdSet ids;
	for (auto& [id, p0] : dict0) {
		mark.insert(id);
		const Property* p1 = PropertyDictionaryGet(dict1, id);
		if (!p1 || p0 != *p1) {
			ids.insert(id);
		}
	}
	for (auto& [id, p1] : dict1) {
		if (!mark.contains(id)) {
			const Property* p0 = PropertyDictionaryGet(dict0, id);
			if (!p0 || p1 != *p0) {
				ids.insert(id);
			}
		}
	}
	return ids;
}

static PropertyFloat ComputeOrigin(const Property* p) {
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
	const Property* originX = e->GetComputedProperty(PropertyId::PerspectiveOriginX);
	const Property* originY = e->GetComputedProperty(PropertyId::PerspectiveOriginY);
	float x = ComputeOrigin(originX).ComputeW(e);
	float y = ComputeOrigin(originY).ComputeH(e);
	return { x, y, 0.f };
}

Element::Element(Document* owner, const std::string& tag)
	: Node(Node::Type::Element)
	, tag(tag)
	, owner_document(owner)
{
	assert(tag == StringUtilities::ToLower(tag));
	assert(owner);
}

Element::~Element() {
	assert(parent == nullptr);
	SetDataModel(nullptr);
	for (auto& child : childnodes) {
		child->SetParentNode(nullptr);
	}
	for (const auto& listener : listeners) {
		listener->OnDetach(this);
	}
}

void Element::Update() {
	UpdateStructure();
	UpdateDefinition();
	UpdateProperties();
	HandleTransitionProperty();
	HandleAnimationProperty();
	UpdateStackingContext();
	for (auto& child : children) {
		child->Update();
	}
}

void Element::UpdateAnimations() {
	AdvanceAnimations();
	for (auto& child : children) {
		child->UpdateAnimations();
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

	size_t i = 0;
	for (; i < stacking_context.size() && stacking_context[i]->GetZIndex() < 0; ++i) {
		stacking_context[i]->Render();
	}
	SetRednerStatus();
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

	std::string classes = GetClassName();
	if (!classes.empty()) {
		classes = StringUtilities::Replace(classes, ' ', '.');
		address += ".";
		address += classes;
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

bool Element::IsPointWithinElement(Point point) {
	bool ignorePointerEvents = Style::PointerEvents(GetComputedProperty(PropertyId::PointerEvents)->Get<PropertyKeyword>()) == Style::PointerEvents::None;
	if (ignorePointerEvents) {
		return false;
	}
	return Project(point) && Rect { {}, GetBounds().size }.Contains(point);
}

float Element::GetZIndex() const {
	return z_index;
}

float Element::GetFontSize() const {
	return font_size;
}

static float ComputeFontsize(const Property* property, Element* element) {
	PropertyFloat fv = property->Get<PropertyFloat>();
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
	if (auto p = GetComputedLocalProperty(PropertyId::FontSize))
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
	const Property* property = GetComputedProperty(PropertyId::Opacity);
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
	attributes[name] = value;
    ElementAttributes changed_attributes;
    changed_attributes.emplace(name, value);
	OnAttributeChange(changed_attributes);
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
				Text* e = owner_document->CreateTextNode(arg);
				if (e) {
					AppendChild(e);
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

void Element::AppendChild(Node* node) { 
	Element* p = node->GetParentNode();
	if (p) {
		p->RemoveChild(node).release();
	}
	GetLayout().InsertChild(node->GetLayout(), (uint32_t)childnodes.size());
	childnodes.emplace_back(node);
	if (Element* e = dynamic_cast<Element*>(node)) {
		children.emplace_back(e);
	}
	node->SetParentNode(this);
	DirtyStackingContext();
	DirtyStructure();
}

std::unique_ptr<Node> Element::RemoveChild(Node* node) {
	size_t index = GetChildNodeIndex(node);
	if (index == size_t(-1)) {
		return nullptr;
	}
	auto detached_child = std::move(childnodes[index]);
	childnodes.erase(childnodes.begin() + index);
	if (Element* e = dynamic_cast<Element*>(node)) {
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
	return std::move(detached_child);
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
	if (Element* e = dynamic_cast<Element*>(node)) {
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
	for (auto& child : childnodes) {
		child->SetParentNode(nullptr);
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
		PropertyDictionary properties;
		StyleSheetParser parser;
		parser.ParseProperties(properties, it->second);

		for (const auto& name_value : properties) {
			SetProperty(name_value.first, &name_value.second);
		}
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

	if (changed_properties.contains(PropertyId::Display)) {
		// Due to structural pseudo-classes, this may change the element definition in siblings and parent.
		// However, the definitions will only be changed on the next update loop which may result in jarring behavior for one @frame.
		// A possible workaround is to add the parent to a list of elements that need to be updated again.
		if (parent != nullptr)
			parent->DirtyStructure();
	}

	if (changed_properties.contains(PropertyId::ZIndex)) {
		float new_z_index = 0;
		const Property* property = GetComputedProperty(PropertyId::ZIndex);
		if (property->Has<PropertyFloat>()) {
			new_z_index = property->Get<PropertyFloat>().value;
		}
		if (z_index != new_z_index) {
			z_index = new_z_index;
			if (parent != nullptr) {
				parent->DirtyStackingContext();
			}
		}
	}

	if (border_radius_changed ||
		changed_properties.contains(PropertyId::BackgroundColor) ||
		changed_properties.contains(PropertyId::BackgroundImage) ||
		changed_properties.contains(PropertyId::Opacity))
	{
		dirty_background = true;
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
		dirty_background = true;
	}

	if (changed_properties.contains(PropertyId::OutlineWidth) ||
		changed_properties.contains(PropertyId::OutlineColor))
	{
		dirty_background = true;
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
		dirty_image = true;
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
		dirty_animation = true;
	}

	if (changed_properties.contains(PropertyId::Transition)) {
		dirty_transition = true;
	}

	for (auto& child : childnodes) {
		if (Text* text = dynamic_cast<Text*>(child.get())) {
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


void Element::SetDataModel(DataModel* new_data_model) {
	assert(!data_model || !new_data_model);
	if (data_model == new_data_model)
		return;
	if (data_model)
		data_model->OnElementRemove(this);
	data_model = new_data_model;
	if (!data_model) {
		for (auto& child : childnodes) {
			child->SetDataModel(nullptr);
		}
		return;
	}
	if (attributes.find("data-for") != attributes.end()) {
		DataUtilities::ApplyDataViewFor(this);
	}
	else {
		DataUtilities::ApplyDataViewsControllers(this);
		for (auto& child : childnodes) {
			child->SetDataModel(data_model);
		}
	}
}

void Element::SetParentNode(Element* _parent) {
	parent = _parent;

	if (parent) {
		DirtyDefinition();
		DirtyInheritedProperties();
	}

	DirtyTransform();
	DirtyClip();
	DirtyPerspective();

	if (!parent) {
		if (data_model)
			SetDataModel(nullptr);
	}
	else {
		auto it = attributes.find("data-model");
		if (it == attributes.end()) {
			SetDataModel(parent->data_model);
		}
		else if (parent->data_model) {
			std::string const& name = it->second;
			Log::Message(Log::Level::Error, "Nested data models are not allowed. Data model '%s' given in element %s.", name.c_str(), GetAddress().c_str());
		}
		else {
			std::string const& name = it->second;
			if (DataModel* model = GetOwnerDocument()->GetDataModelPtr(name)) {
				model->AttachModelRootElement(this);
				SetDataModel(model);
			}
			else {
				Log::Message(Log::Level::Error, "Could not locate data model '%s' in element %s.", name.c_str(), GetAddress().c_str());
			}
		}
	}
}

void Element::UpdateStackingContext() {
	if (!dirty_stacking_context) {
		return;
	}
	dirty_stacking_context = false;
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
	dirty_stacking_context = true;
}

void Element::DirtyStructure() {
	dirty_structure = true;
}

void Element::UpdateStructure() {
	if (dirty_structure) {
		dirty_structure = false;
		DirtyDefinition();
	}
}

void Element::StartAnimation(PropertyId property_id, const Property* start_value, int num_iterations, bool alternate_direction, float delay) {
	double start_time = GetOwnerDocument()->GetCurrentTime() + (double)delay;

	ElementAnimation animation{ property_id, ElementAnimationOrigin::Animation, *start_value, *this, start_time, 0.0f, num_iterations, alternate_direction };
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

bool Element::AddAnimationKeyTime(PropertyId property_id, const Property* target_value, float time, Tween tween) {
	if (!target_value)
		target_value = GetComputedProperty(property_id);
	if (!target_value)
		return false;
	SetProperty(property_id, target_value);
	ElementAnimation* animation = nullptr;
	for (auto& existing_animation : animations) {
		if (existing_animation.GetPropertyId() == property_id) {
			animation = &existing_animation;
			break;
		}
	}
	if (!animation)
		return false;
	return animation->AddKey(time, *target_value, *this, tween);
}

bool Element::StartTransition(PropertyId id, const Transition& transition, const Property& start_value, const Property& target_value) {
	auto it = std::find_if(animations.begin(), animations.end(), [&](const ElementAnimation& el) { return el.GetPropertyId() == id; });

	if (it != animations.end() && !it->IsTransition())
		return false;

	float duration = transition.duration;
	double start_time = GetOwnerDocument()->GetCurrentTime() + (double)transition.delay;

	if (it == animations.end()) {
		// Add transition as new animation
		animations.emplace_back(
			id, ElementAnimationOrigin::Transition, start_value, *this, start_time, 0.0f, 1, false 
		);
		it = (animations.end() - 1);
	}
	else {
		// Replace old transition
		*it = ElementAnimation{ id, ElementAnimationOrigin::Transition, start_value, *this, start_time, 0.0f, 1, false };
	}

	if (!it->AddKey(duration, target_value, *this, transition.tween)) {
		animations.erase(it);
		return false;
	}
	SetAnimationProperty(id, &start_value);
	return true;
}

void Element::HandleTransitionProperty() {
	if (!dirty_transition) {
		return;
	}
	dirty_transition = false;

	// Remove all transitions that are no longer in our local list
	const Transitions* keep_transitions = GetTransition();
	auto it_remove = animations.end();

	if (!keep_transitions) {
		static Transitions dummy = TransitionNone {};
		keep_transitions = &dummy;
	}

	std::visit([&](auto&& arg) {
		using T = std::decay_t<decltype(arg)>;
		if constexpr (std::is_same_v<T, TransitionNone>) {
			it_remove = std::partition(animations.begin(), animations.end(),
				[](const ElementAnimation& animation) -> bool { return !animation.IsTransition(); }
			);
		}
		else if constexpr (std::is_same_v<T, TransitionAll>) {
		}
		else if constexpr (std::is_same_v<T, TransitionList>) {
			// Only remove the transitions that are not in our keep list.
			const auto& keep_transitions_list = arg.transitions;
			it_remove = std::partition(animations.begin(), animations.end(),
				[&keep_transitions_list](const ElementAnimation& animation) -> bool {
					if (!animation.IsTransition())
						return true;
					auto it = keep_transitions_list.find(animation.GetPropertyId());
					bool keep_animation = (it != keep_transitions_list.end());
					return keep_animation;
				}
			);
		}
		else {
			static_assert(always_false_v<T>, "non-exhaustive visitor!");
		}
	}, *keep_transitions);

	if (it_remove == animations.end()) {
		return;
	}

	// We can decide what to do with cancelled transitions here.
	for (auto it = it_remove; it != animations.end(); ++it)
		it->Release(*this);

	animations.erase(it_remove, animations.end());
}

void Element::HandleAnimationProperty() {
	// Note: We are effectively restarting all animations whenever 'dirty_animation' is set. Use the dirty flag with care,
	// or find another approach which only updates actual "dirty" animations.
	if (!dirty_animation) {
		return;
	}
	dirty_animation = false;

	// Remove existing animations
	{
		auto it_remove = std::partition(animations.begin(), animations.end(), 
			[](const ElementAnimation & animation) { return animation.IsTransition(); }
		);
		for (auto it = it_remove; it != animations.end(); ++it)
			it->Release(*this);
		animations.erase(it_remove, animations.end());
	}

	// Start animations
	const Property* property = GetComputedProperty(PropertyId::Animation);
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
		const Keyframes* keyframes_ptr = stylesheet.GetKeyframes(animation.name);
		if (keyframes_ptr && keyframes_ptr->blocks.size() >= 1 && !animation.paused) {
			auto& property_ids = keyframes_ptr->property_ids;
			auto& blocks = keyframes_ptr->blocks;
			bool has_from_key = (blocks[0].normalized_time == 0);
			bool has_to_key = (blocks.back().normalized_time == 1);
			// If the first key defines initial conditions for a given property, use those values, else, use this element's current values.
			for (PropertyId id : property_ids) {
				const Property* start = nullptr;
				if (has_from_key) {
					start = PropertyDictionaryGet(blocks[0].properties, id);
				}
				if (!start) {
					start = GetComputedProperty(id);
				}
				if (start) {
					StartAnimation(id, start, animation.num_iterations, animation.alternate, animation.transition.delay);
				}
			}
			// Add middle keys: Need to skip the first and last keys if they set the initial and end conditions, respectively.
			for (int i = (has_from_key ? 1 : 0); i < (int)blocks.size() + (has_to_key ? -1 : 0); i++) {
				// Add properties of current key to animation
				float time = blocks[i].normalized_time * animation.transition.duration;
				for (auto& property : blocks[i].properties)
					AddAnimationKeyTime(property.first, &property.second, time, animation.transition.tween);
			}
			// If the last key defines end conditions for a given property, use those values, else, use this element's current values.
			float time = animation.transition.duration;
			for (PropertyId id : property_ids)
				AddAnimationKeyTime(id, (has_to_key ? PropertyDictionaryGet(blocks.back().properties, id) : nullptr), time, animation.transition.tween);
		}
	}
}

void Element::AdvanceAnimations() {
	if (animations.empty()) {
		return;
	}
	double time = GetOwnerDocument()->GetCurrentTime();
	for (auto& animation : animations) {
		animation.UpdateAndGetProperty(time, *this);
	}
	auto it_completed = std::partition(animations.begin(), animations.end(), [](const ElementAnimation& animation) { return !animation.IsComplete(); });
	std::vector<bool> is_transition;
	is_transition.reserve(animations.end() - it_completed);
	for (auto it = it_completed; it != animations.end(); ++it) {
		is_transition.push_back(it->IsTransition());
		it->Release(*this);
	}
	animations.erase(it_completed, animations.end());
	UpdateProperties();
}

void Element::DirtyPerspective() {
	dirty_perspective = true;
}

void Element::UpdateTransform() {
	if (!dirty_transform)
		return;
	dirty_transform = false;
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
	if (!dirty_perspective)
		return;
	dirty_perspective = false;
	const Property* p = GetComputedProperty(PropertyId::Perspective);
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
	if (dirty_background) {
		if (!geometry_background) {
			geometry_background.reset(new Geometry);
		}
		else {
			geometry_background->Release();
		}
		ElementBackgroundBorder::GenerateGeometry(this, *geometry_background, padding_edge);
		dirty_background = false;
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
	dirty_background = true;
	dirty_image = true;
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
	UpdateStackingContext();
	for (auto iter = stacking_context.rbegin(); iter != stacking_context.rend() && (*iter)->GetZIndex() >= 0; ++iter) {
		Element* res = (*iter)->ElementFromPoint(point);
		if (res) {
			return res;
		}
	}
	if (IsPointWithinElement(point)) {
		return this;
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
	if (!dirty_clip)
		return;
	dirty_clip = false;
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

void Element::SetRednerStatus() {
	auto render = GetRenderInterface();
	render->SetTransform(transform);
	switch (clip.type) {
	case Clip::Type::None:    render->SetClipRect();             break;
	case Clip::Type::Scissor: render->SetClipRect(clip.scissor); break;
	case Clip::Type::Shader:  render->SetClipRect(clip.shader);  break;
	}
}

void Element::DirtyTransform() {
	dirty_transform = true;
}

void Element::DirtyClip() {
	dirty_clip = true;
}

void Element::AddEventListener(EventListener* listener) {
	auto it = std::find(listeners.begin(), listeners.end(), listener);
	if (it == listeners.end()) {
		listeners.emplace(it, listener);
	}
}

void Element::RemoveEventListener(EventListener* listener) {
	auto it = std::find(listeners.begin(), listeners.end(), listener);
	if (it != listeners.end()) {
		listeners.erase(it);
		listener->OnDetach(this);
	}
}

bool Element::DispatchEvent(const std::string& type, int parameters, bool interruptible, bool bubbles) {
	Event event(this, type, parameters, interruptible);
	return Rml::DispatchEvent(event, bubbles);
}

void Element::RemoveAllEvents() {
	for (const auto& listener : listeners) {
		listener->OnDetach(this);
	}
	listeners.clear();
	for (auto& child : children) {
		child->RemoveAllEvents();
	}
}

std::vector<EventListener*> const& Element::GetEventListeners() const {
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
	SetProperty(PropertyId::ScrollLeft, &value);
}

void Element::SetScrollTop(float v) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	Size offset { 0, v };
	UpdateScrollOffset(offset);
	Property value(offset.h, PropertyUnit::PX);
	SetProperty(PropertyId::ScrollTop, &value);
}

void Element::SetScrollInsets(const EdgeInsets<float>& insets) {
	if (GetLayout().GetOverflow() != Layout::Overflow::Scroll) {
		return;
	}
	scroll_insets = insets;
	Size offset = GetScrollOffset();
	UpdateScrollOffset(offset);

	Property left(offset.w, PropertyUnit::PX);
	SetProperty(PropertyId::ScrollLeft, &left);

	Property top(offset.h, PropertyUnit::PX);
	SetProperty(PropertyId::ScrollTop, &top);
}

template <typename T>
void clamp(T& v, T min, T max) {
	assert(min <= max);
	if (v < min) {
		v = min;
	}
	else if (v > max) {
		v = max;
	}
}

void clamp(Size& s, Rect r) {
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

std::string Element::GetClassName() const {
	std::string class_names;
	for (size_t i = 0; i < classes.size(); i++) {
		if (i != 0) {
			class_names += " ";
		}
		class_names += classes[i];
	}
	return class_names;
}

void Element::DirtyPropertiesWithUnitRecursive(PropertyUnit unit) {
	ForeachProperties([&](PropertyId id, const Property& property) {
		if (property.Has<PropertyFloat>() && unit == property.Get<PropertyFloat>().unit) {
			DirtyProperty(id);
		}
	});
	for (auto& child : children) {
		child->DirtyPropertiesWithUnitRecursive(unit);
	}
}

const Property* Element::GetProperty(PropertyId id) const {
	return PropertyDictionaryGet(inline_properties, id);
}

const Property* Element::GetComputedLocalProperty(PropertyId id) const {
	const Property* property = GetAnimationProperty(id);
	if (property)
		return property;
	property = PropertyDictionaryGet(inline_properties, id);
	if (property)
		return property;
	if (definition_properties)
		return PropertyDictionaryGet(definition_properties->prop, id);
	return nullptr;
}


void Element::SetProperty(const std::string& name, std::optional<std::string> value) {
	if (value) {
		PropertyDictionary properties;
		if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, *value)) {
			Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value->c_str());
			return;
		}
		for (auto& property : properties) {
			SetProperty(property.first, &property.second);
		}
	}
	else {
		PropertyIdSet properties;
		if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name)) {
			Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s;'.", name.c_str());
			return;
		}
		for (auto property_id : properties) {
			SetProperty(property_id);
		}
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
		const Property* property = GetProperty(property_id);
		if (property) {
			if (!res.empty()) {
				res += " ";
			}
			res += property->ToString();
		}
	}
	return res;
}

const Property* Element::GetAnimationProperty(PropertyId id) const {
	return PropertyDictionaryGet(animation_properties, id);
}

const Property* Element::GetComputedProperty(PropertyId id) const {
	const Property* property = GetComputedLocalProperty(id);
	if (property)
		return property;
	const PropertyDefinition* propertyDef = StyleSheetSpecification::GetPropertyDefinition(id);
	if (!propertyDef)
		return nullptr;
	if (propertyDef->IsInherited()) {
		Element* parent = GetParentNode();
		while (parent) {
			const Property* parent_property = parent->GetComputedLocalProperty(id);
			if (parent_property)
				return parent_property;
			parent = parent->GetParentNode();
		}
	}
	auto const& def = propertyDef->GetDefaultValue();
	if (def) {
		return &*def;
	}
	return nullptr;
}

const Transitions* Element::GetTransition(const PropertyDictionary* def) const {
	const Property* property = PropertyDictionaryGet(inline_properties, PropertyId::Transition);
	if (!property) {
		if (def) {
			property = PropertyDictionaryGet(*def, PropertyId::Transition);
		}
		else if (definition_properties) {
			property = PropertyDictionaryGet(definition_properties->prop, PropertyId::Transition);
		}
	}
	if (!property) {
		return nullptr;
	}
	return &property->Get<Transitions>();
}

void Element::TransitionPropertyChanges(const PropertyIdSet& properties, const PropertyDictionary& new_definition) {
	const Transitions* transitions = GetTransition(&new_definition);
	if (!transitions) {
		return;
	}
	
	auto add_transition = [&](PropertyId id, const Transition& transition) {
		const Property* from = GetComputedProperty(id);
		const Property* to = PropertyDictionaryGet(new_definition, id);
		if (from && to && (*from != *to)) {
			return StartTransition(id, transition, *from, *to);
		}
		return false;
	};

	std::visit([&](auto&& arg) {
		using T = std::decay_t<decltype(arg)>;
		if constexpr (std::is_same_v<T, TransitionNone>) {
		}
		else if constexpr (std::is_same_v<T, TransitionAll>) {
			for (auto const& id : properties) {
				add_transition(id, arg);
			}
		}
		else if constexpr (std::is_same_v<T, TransitionList>) {
			for (auto const& [id, transition] : arg.transitions) {
				if (properties.contains(id)) {
					add_transition(id, transition);
				}
			}
		}
		else {
			static_assert(always_false_v<T>, "non-exhaustive visitor!");
		}
	}, *transitions);
}

void Element::TransitionPropertyChanges(const Transitions* transitions, PropertyId id, const Property& old_property) {
	const Property* new_property = GetComputedProperty(id);
	if (!new_property || (*new_property == old_property)) {
		return;
	}
	
	std::visit([&](auto&& arg) {
		using T = std::decay_t<decltype(arg)>;
		if constexpr (std::is_same_v<T, TransitionNone>) {
		}
		else if constexpr (std::is_same_v<T, TransitionAll>) {
			StartTransition(id, arg, old_property, *new_property);
		}
		else if constexpr (std::is_same_v<T, TransitionList>) {
			auto iter = arg.transitions.find(id);
			if (iter != arg.transitions.end()) {
				StartTransition(id, iter->second, old_property, *new_property);
			}
		}
		else {
			static_assert(always_false_v<T>, "non-exhaustive visitor!");
		}
	}, *transitions);
}

void Element::UpdateDefinition() {
	if (!dirty_definition) {
		return;
	}
	dirty_definition = false;
	SharedPtr<StyleSheetPropertyDictionary> new_definition = GetStyleSheet().GetElementDefinition(this);
	if (new_definition != definition_properties) {
		if (definition_properties && new_definition) {
			PropertyIdSet changed_properties = PropertyDictionaryDiff(definition_properties->prop, new_definition->prop);
			for (PropertyId id : changed_properties) {
				if (PropertyDictionaryGet(inline_properties, id)) {
					changed_properties.erase(id);
				}
			}
			if (!changed_properties.empty()) {
				TransitionPropertyChanges(changed_properties, new_definition->prop);
			}
			definition_properties = new_definition;
			DirtyProperties(changed_properties);
		}
		else if (definition_properties) {
			PropertyIdSet changed_properties = PropertyDictionaryGetIds(definition_properties->prop);
			definition_properties = new_definition;
			DirtyProperties(changed_properties);
		}
		else if (new_definition) {
			PropertyIdSet changed_properties = PropertyDictionaryGetIds(new_definition->prop);
			definition_properties = new_definition;
			DirtyProperties(changed_properties);
		}
		else {
			PropertyIdSet changed_properties;
			definition_properties = new_definition;
			DirtyProperties(changed_properties);
		}
	}
	for (auto& child : children) {
		child->DirtyDefinition();
	}
}

void Element::UpdateProperty(PropertyId id, const Property* property) {
	if (property) {
		inline_properties.insert_or_assign(id, *property);
	}
	else if (!inline_properties.erase(id)) {
		return;
	}
	DirtyProperty(id);
}

void Element::SetProperty(PropertyId id, const Property* newProperty) {
	const Transitions* transitions = GetTransition();
	if (!transitions || std::holds_alternative<TransitionNone>(*transitions)) {
		UpdateProperty(id, newProperty);
		return;
	}
	const Property* ptrProperty = GetComputedProperty(id);
	if (!ptrProperty) {
		UpdateProperty(id, newProperty);
		return;
	}
	Property oldProperty = *ptrProperty;
	UpdateProperty(id, newProperty);
	TransitionPropertyChanges(transitions, id, oldProperty);
}

void Element::SetAnimationProperty(PropertyId id, const Property* property) {
	if (property) {
		animation_properties.insert_or_assign(id, *property);
	}
	else if (!animation_properties.erase(id)) {
		return;
	}
	DirtyProperty(id);
}

void Element::DirtyDefinition() {
	dirty_definition = true;
}

void Element::DirtyInheritedProperties() {
	dirty_properties |= StyleSheetSpecification::GetRegisteredInheritedProperties();
}

void Element::ForeachProperties(std::function<void(PropertyId id, const Property& property)> f) {
	PropertyIdSet mark;
	for (auto& [id, property] : animation_properties) {
		mark.insert(id);
		f(id, property);
	}
	for (auto& [id, property] : inline_properties) {
		if (!mark.contains(id)) {
			mark.insert(id);
			f(id, property);
		}
	}
	if (definition_properties) {
		for (auto& [id, property] : definition_properties->prop) {
			if (!mark.contains(id)) {
				f(id, property);
			}
		}
	}
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

	bool dirty_em_properties = false;
	if (dirty_properties.contains(PropertyId::FontSize)) {
		if (UpdataFontSize()) {
			dirty_em_properties = true;
			dirty_properties.insert(PropertyId::LineHeight);
		}
	}

	ForeachProperties([&](PropertyId id, const Property& property){
		if (dirty_em_properties && property.Has<PropertyFloat>() && property.Get<PropertyFloat>().unit == PropertyUnit::EM)
			dirty_properties.insert(id);
		if (!dirty_properties.contains(id)) {
			return;
		}

		switch (id) {
		case PropertyId::Left:
		case PropertyId::Top:
		case PropertyId::Right:
		case PropertyId::Bottom:
		case PropertyId::MarginLeft:
		case PropertyId::MarginTop:
		case PropertyId::MarginRight:
		case PropertyId::MarginBottom:
		case PropertyId::PaddingLeft:
		case PropertyId::PaddingTop:
		case PropertyId::PaddingRight:
		case PropertyId::PaddingBottom:
		case PropertyId::BorderLeftWidth:
		case PropertyId::BorderTopWidth:
		case PropertyId::BorderRightWidth:
		case PropertyId::BorderBottomWidth:
		case PropertyId::Height:
		case PropertyId::Width:
		case PropertyId::MaxHeight:
		case PropertyId::MinHeight:
		case PropertyId::MaxWidth:
		case PropertyId::MinWidth:
		case PropertyId::Position:
		case PropertyId::Display:
		case PropertyId::Overflow:
		case PropertyId::AlignContent:
		case PropertyId::AlignItems:
		case PropertyId::AlignSelf:
		case PropertyId::Direction:
		case PropertyId::FlexDirection:
		case PropertyId::FlexWrap:
		case PropertyId::JustifyContent:
		case PropertyId::AspectRatio:
		case PropertyId::Flex:
		case PropertyId::FlexBasis:
		case PropertyId::FlexGrow:
		case PropertyId::FlexShrink:
			GetLayout().SetProperty(id, &property, this);
			break;
		default:
			break;
		}
	});

	PropertyIdSet dirty_inherited_properties = (dirty_properties & StyleSheetSpecification::GetRegisteredInheritedProperties());
	if (!dirty_inherited_properties.empty()) {
		for (auto& child : children) {
			child->DirtyProperties(dirty_inherited_properties);
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

}
