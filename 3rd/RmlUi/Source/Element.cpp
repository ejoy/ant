#include "../Include/RmlUi/Element.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/PropertyIdSet.h"
#include "../Include/RmlUi/PropertyDefinition.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Transform.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/EventListener.h"
#include "../Include/RmlUi/Time.h"
#include "../Include/RmlUi/Event.h"
#include "../Include/RmlUi/Plugin.h"
#include "../Include/RmlUi/ElementStyle.h"
#include "../Include/RmlUi/Property.h"
#include "DataModel.h"
#include "ElementAnimation.h"
#include "ElementBackgroundBorder.h"
#include "EventDispatcher.h"
#include "ElementBackgroundImage.h"
#include "StyleSheetParser.h"
#include "StyleSheetNode.h"
#include "StyleSheetFactory.h"
#include "HtmlParser.h"
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
		ids.Insert(id);
	}
	return ids;
}

static PropertyIdSet PropertyDictionaryDiff(const PropertyDictionary& dict0, const PropertyDictionary& dict1) {
	PropertyIdSet mark;
	PropertyIdSet ids;
	for (auto& [id, p0] : dict0) {
		mark.Insert(id);
		const Property* p1 = PropertyDictionaryGet(dict1, id);
		if (p1 && p0 != *p1) {
			ids.Insert(id);
		}
	}
	for (auto& [id, p1] : dict1) {
		if (!mark.Contains(id)) {
			const Property* p0 = PropertyDictionaryGet(dict0, id);
			if (p0 && p1 != *p0) {
				ids.Insert(id);
			}
		}
	}
	return ids;
}

Element::Element(Document* owner, const std::string& tag)
	: tag(tag)
	, owner_document(owner)
{
	assert(tag == StringUtilities::ToLower(tag));
	assert(owner);
}

Element::~Element() {
	assert(parent == nullptr);
	SetDataModel(nullptr);
	for (auto& child : children) {
		child->SetParent(nullptr);
	}
	for (const auto& listener : listeners) {
		listener->OnDetach(this);
	}
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

const std::shared_ptr<StyleSheet>& Element::GetStyleSheet() const {
	return GetOwnerDocument()->GetStyleSheet();
}

std::string Element::GetAddress(bool include_pseudo_classes, bool include_parents) const {
	std::string address(tag);

	if (!id.empty()) {
		address += "#";
		address += id;
	}

	std::string classes = GetClassNames();
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
	bool ignorePointerEvents = Style::PointerEvents(GetComputedProperty(PropertyId::PointerEvents)->GetKeyword()) == Style::PointerEvents::None;
	if (ignorePointerEvents) {
		return false;
	}
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
			return fontSize * 0.01f * property->GetFloat();
		}
		return fontSize * property->GetFloat();
	}
	if (property->unit == Property::REM) {
		if (element == element->GetOwnerDocument()->GetBody()) {
			return property->GetFloat() * 16;
		}
	}
	return ComputeProperty(property, element);
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
	return property->GetFloat();
}

bool Element::SetProperty(const std::string& name, const std::string& value) {
	PropertyDictionary properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name, value)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s: %s;'.", name.c_str(), value.c_str());
		return false;
	}
	for (auto& property : properties) {
		if (!SetProperty(property.first, property.second))
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
	for (auto& property : properties) {
		if (!SetPropertyImmediate(property.first, property.second))
			return false;
	}
	return true;
}

void Element::RemoveProperty(const std::string& name) {
	PropertyIdSet properties;
	if (!StyleSheetSpecification::ParsePropertyDeclaration(properties, name)) {
		Log::Message(Log::Level::Warning, "Syntax error parsing inline property declaration '%s;'.", name.c_str());
		return;
	}
	for (auto property_id : properties) {
		RemoveProperty(property_id);
	}
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
	if (it != attributes.end())
	{
		attributes.erase(it);

		ElementAttributes changed_attributes;
		changed_attributes.emplace(name, std::string());
		OnAttributeChange(changed_attributes);
	}
}

void Element::SetAttributes(const ElementAttributes& _attributes) {
	attributes.reserve(attributes.size() + _attributes.size());
	for (auto& pair : _attributes)
		attributes[pair.first] = pair.second;
	OnAttributeChange(_attributes);
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

Element* Element::GetChild(int index) const {
	if (index < 0 || index >= (int) children.size())
		return nullptr;
	return children[index].get();
}

int Element::GetNumChildren() const {
	return (int)children.size();
}

// TODO: remove this function, duplicate code in Document.cpp
static bool isDataViewElement(Element* e) {
	for (const std::string& name : Factory::GetStructuralDataViewAttributeNames()) {
		if (e->GetTagName() == name) {
			return true;
		}
	}
	return false;
}

class EmbedHtmlHandler : public HtmlHandler {
	Document*				m_doc{ nullptr };
	ElementAttributes		m_attributes;
	std::shared_ptr<StyleSheet> m_style_sheet;
	std::stack<Element*>	m_stack;
	Element*				m_parent{ nullptr };
	Element*				m_current{ nullptr };
	size_t					m_line{ 0 };
	bool				    m_inner_xml = false;
public:
	EmbedHtmlHandler(Element* current)
		: m_current{ current }
	{
		m_doc = m_current->GetOwnerDocument();
	}
	void OnInnerXML(bool inner) override { m_inner_xml = inner; }
	bool IsEmbed() override { return true; }
	void OnDocumentEnd() override {
		if (m_style_sheet) {
			m_doc->SetStyleSheet(std::move(m_style_sheet));
		}
	}
	void OnElementBegin(const char* szName) override {
		if (m_inner_xml) {
			return;
		}
		m_attributes.clear();
		if (!m_current) {
			return;
		}
		m_stack.push(m_current);
		m_parent = m_current;
		m_current = new Element(m_doc, szName);
	}
	void OnElementClose() override {
		if (m_inner_xml) {
			return;
		}
		if (m_parent && m_current) {
			m_parent->AppendChild(ElementPtr(m_current));
		}
	}
	void OnElementEnd(const  char* szName, const std::string& inner_xml_data) override {
		if (!m_current || m_inner_xml) {
			return;
		}

		if (!inner_xml_data.empty()) {
			ElementUtilities::ApplyStructuralDataViews(m_current, inner_xml_data);
		}

		if (m_stack.empty()) {
			m_current = nullptr;
		}
		else {
			m_current = m_stack.top();
			m_stack.pop();
		}
	}
	void OnCloseSingleElement(const  char* szName) override {
		OnElementEnd(szName, {});
	}
	void OnAttribute(const char* szName, const char* szValue) override {
		if (m_inner_xml) {
			return;
		}
		if (m_current) {
			m_current->SetAttribute(szName, szValue);
		}
		else {
			m_attributes.emplace(szName, szValue);
		}
	}
	void OnTextEnd(const char* szValue) override {
		if (m_inner_xml) {
			return;
		}
		if (m_current) {
			if (isDataViewElement(m_current) && ElementUtilities::ApplyStructuralDataViews(m_current, szValue)) {
				return;
			}
			m_current->CreateTextNode(szValue);
		}
	}
	
	void OnStyleBegin(unsigned int line) override {
		m_line = line;
	}
	void LoadInlineStyle(const std::string& content, const std::string& source_path, int line) {
		std::unique_ptr<StyleSheet> inline_sheet = std::make_unique<StyleSheet>();
		auto stream = std::make_unique<Stream>(source_path, (const uint8_t*)content.data(), content.size());
		if (inline_sheet->LoadStyleSheet(stream.get(), line)) {
			if (m_style_sheet) {
				m_style_sheet->CombineStyleSheet(*inline_sheet);
			}
			else
				m_style_sheet = std::move(inline_sheet);
		}
		stream.reset();
	}
	void LoadExternalStyle(const std::string& source_path) {
		std::shared_ptr<StyleSheet> sub_sheet = StyleSheetFactory::GetStyleSheet(source_path);
		if (sub_sheet) {
			if (m_style_sheet) {
				m_style_sheet->CombineStyleSheet(*sub_sheet);
			}
			else
				m_style_sheet = sub_sheet;
		}
		else
			Log::Message(Log::Level::Error, "Failed to load style sheet %s.", source_path.c_str());
	}
	void OnStyleEnd(const char* szValue) override {
		auto it = m_attributes.find("path");
		if (it == m_attributes.end()) {
			LoadInlineStyle(szValue, m_doc->GetSourceURL(), m_line);
		}
		else {
			LoadExternalStyle(it->second);
		}
	}
};

void Element::SetInnerRML(const std::string& rml) {
	if (rml.empty()) {
		return;
	}
	HtmlParser parser;
	EmbedHtmlHandler handler(parent);
	parser.Parse(rml, &handler);
}

bool Element::CreateTextNode(const std::string& str) {
	if (std::all_of(str.begin(), str.end(), &StringUtilities::IsWhitespace))
		return true;
	bool has_data_expression = false;
	bool inside_brackets = false;
	char previous = 0;
	for (const char c : str) {
		if (inside_brackets) {
			if (c == '}' && previous == '}') {
				has_data_expression = true;
				break;
			}
		}
		else if (c == '{' && previous == '{') {
				inside_brackets = true;
		}
		previous = c;
	}
	ElementPtr text(new ElementText(GetOwnerDocument(), str));
	if (!text) {
		Log::Message(Log::Level::Error, "Failed to instance text element '%s', instancer returned nullptr.", str.c_str());
		return false;
	}
	if (has_data_expression) {
		text->SetAttribute("data-text", std::string());
	}
	AppendChild(std::move(text));
	return true;
}

Element* Element::AppendChild(ElementPtr child) {
	assert(child);
	Element* child_ptr = child.get();
	GetLayout().InsertChild(child->GetLayout(), (uint32_t)children.size());
	children.insert(children.end(), std::move(child));
	child_ptr->SetParent(this);
	DirtyStackingContext();
	DirtyStructure();
	return child_ptr;
}

Element* Element::InsertBefore(ElementPtr child, Element* adjacent_element) {
	assert(child);
	size_t child_index = 0;
	bool found_child = false;
	if (adjacent_element) {
		for (child_index = 0; child_index < children.size(); child_index++) {
			if (children[child_index].get() == adjacent_element) {
				found_child = true;
				break;
			}
		}
	}

	Element* child_ptr = nullptr;

	if (found_child) {
		child_ptr = child.get();

		GetLayout().InsertChild(child->GetLayout(), (uint32_t)child_index);
		children.insert(children.begin() + child_index, std::move(child));
		child_ptr->SetParent(this);
		DirtyStackingContext();
		DirtyStructure();
	}
	else {
		child_ptr = AppendChild(std::move(child));
	}	

	return child_ptr;
}

ElementPtr Element::RemoveChild(Element* child) {
	size_t child_index = 0;

	for (auto itr = children.begin(); itr != children.end(); ++itr) {
		// Add the element to the delete list
		if (itr->get() == child) {
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
		return GetOwnerDocument()->GetBody();
	else if (id == "#parent")
		return this->parent;
	Element* search_root = GetOwnerDocument()->GetBody();
	if (search_root == nullptr)
		search_root = this;
		
	// Breadth first search on elements for the corresponding id
	typedef std::queue<Element*> SearchQueue;
	SearchQueue search_queue;
	search_queue.push(search_root);

	while (!search_queue.empty()) {
		Element* element = search_queue.front();
		search_queue.pop();
		
		if (GetId() == id) {
			return element;
		}
		
		for (int i = 0; i < GetNumChildren(); i++)
			search_queue.push(GetChild(i));
	}
	return nullptr;
}

void Element::GetElementsByTagName(ElementList& elements, const std::string& tag) {
	// Breadth first search on elements for the corresponding id
	typedef std::queue< Element* > SearchQueue;
	SearchQueue search_queue;
	for (int i = 0; i < GetNumChildren(); ++i)
		search_queue.push(GetChild(i));

	while (!search_queue.empty()) {
		Element* element = search_queue.front();
		search_queue.pop();

		if (GetTagName() == tag)
			elements.push_back(element);

		for (int i = 0; i < GetNumChildren(); i++)
			search_queue.push(GetChild(i));
	}
}

void Element::GetElementsByClassName(ElementList& elements, const std::string& class_name) {
	// Breadth first search on elements for the corresponding id
	typedef std::queue< Element* > SearchQueue;
	SearchQueue search_queue;
	for (int i = 0; i < GetNumChildren(); ++i)
		search_queue.push(GetChild(i));

	while (!search_queue.empty()) {
		Element* element = search_queue.front();
		search_queue.pop();

		if (IsClassSet(class_name))
			elements.push_back(element);

		for (int i = 0; i < GetNumChildren(); i++)
			search_queue.push(GetChild(i));
	}
}

static Element* QuerySelectorMatchRecursive(const StyleSheetNodeListRaw& nodes, Element* element) {
	for (int i = 0; i < element->GetNumChildren(); i++) {
		Element* child = element->GetChild(i);
		for (const StyleSheetNode* node : nodes) {
			if (node->IsApplicable(child, false))
				return child;
		}
		Element* matching_element = QuerySelectorMatchRecursive(nodes, child);
		if (matching_element)
			return matching_element;
	}

	return nullptr;
}

static void QuerySelectorAllMatchRecursive(ElementList& matching_elements, const StyleSheetNodeListRaw& nodes, Element* element) {
	for (int i = 0; i < element->GetNumChildren(); i++) {
		Element* child = element->GetChild(i);
		for (const StyleSheetNode* node : nodes) {
			if (node->IsApplicable(child, false)) {
				matching_elements.push_back(child);
				break;
			}
		}
		QuerySelectorAllMatchRecursive(matching_elements, nodes, child);
	}
}

Element* Element::QuerySelector(const std::string& selectors) {
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

DataModel* Element::GetDataModel() const {
	return data_model;
}

void Element::OnAttributeChange(const ElementAttributes& changed_attributes) {
	auto it = changed_attributes.find("id");
	if (it != changed_attributes.end()) {
		id = it->second;
		DirtyDefinition();
	}

	it = changed_attributes.find("class");
	if (it != changed_attributes.end()) {
		SetClassNames(it->second);
	}

	it = changed_attributes.find("style");
	if (it != changed_attributes.end()) {
		PropertyDictionary properties;
		StyleSheetParser parser;
		parser.ParseProperties(properties, it->second);

		for (const auto& name_value : properties) {
			SetProperty(name_value.first, name_value.second);
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
		const Property* property = GetComputedProperty(PropertyId::ZIndex);
		if (property->unit != Property::KEYWORD) {
			new_z_index = property->GetFloat();
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
		dirty_background = true;
	}

	if (changed_properties.Contains(PropertyId::OutlineWidth) ||
		changed_properties.Contains(PropertyId::OutlineColor))
	{
		dirty_background = true;
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
		if (clip.type != Clip::Type::None) {
			DirtyClip();
		}
	}

	if (changed_properties.Contains(PropertyId::Overflow)) {
		DirtyClip();
	}

	if (changed_properties.Contains(PropertyId::Animation)) {
		dirty_animation = true;
	}

	if (changed_properties.Contains(PropertyId::Transition)) {
		dirty_transition = true;
	}

	for (auto& child : children) {
		if (child->GetType() == Node::Type::Text) {
			child->OnChange(changed_properties);
		}
	}
}

const Style::ComputedValues& Element::GetComputedValues() const {
	return computed_values;
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
	assert(!data_model || !new_data_model);

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
	assert(!parent || !_parent);
	if (parent) {
		assert(GetOwnerDocument() == parent->GetOwnerDocument());
	}

	parent = _parent;
	Node::SetParentNode(parent);

	if (parent) {
		// We need to update our definition and make sure we inherit the properties of our new parent.
		DirtyDefinition();
		DirtyInheritedProperties();
	}

	// The transform state may require recalculation.
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

void Element::StartAnimation(PropertyId property_id, const Property* start_value, int num_iterations, bool alternate_direction, float delay, bool initiated_by_animation_property) {
	Property value;
	if (start_value) {
		value = *start_value;
		if (!value.definition)
			if (auto default_value = GetComputedProperty(property_id))
				value.definition = default_value->definition;	
	}
	else if (auto default_value = GetComputedProperty(property_id)) {
		value = *default_value;
	}
	if (!value.definition) {
		return;
	}
	ElementAnimationOrigin origin = (initiated_by_animation_property ? ElementAnimationOrigin::Animation : ElementAnimationOrigin::User);
	double start_time = Time::Now() + (double)delay;

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

bool Element::AddAnimationKeyTime(PropertyId property_id, const Property* target_value, float time, Tween tween) {
	if (!target_value)
		target_value = GetComputedProperty(property_id);
	if (!target_value)
		return false;
	SetProperty(property_id, *target_value);
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

bool Element::StartTransition(const Transition& transition, const Property& start_value, const Property & target_value) {
	auto it = std::find_if(animations.begin(), animations.end(), [&](const ElementAnimation& el) { return el.GetPropertyId() == transition.id; });

	if (it != animations.end() && !it->IsTransition())
		return false;

	float duration = transition.duration;
	double start_time = Time::Now() + (double)transition.delay;

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

	if (!it->AddKey(duration, target_value, *this, transition.tween)) {
		animations.erase(it);
		return false;
	}
	SetAnimationProperty(transition.id, start_value);
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

void Element::HandleAnimationProperty() {
	// Note: We are effectively restarting all animations whenever 'dirty_animation' is set. Use the dirty flag with care,
	// or find another approach which only updates actual "dirty" animations.
	if (!dirty_animation) {
		return;
	}
	dirty_animation = false;

	const AnimationList& animation_list = computed_values.animation;
	bool element_has_animations = (!animation_list.empty() || !animations.empty());
	StyleSheet* stylesheet = nullptr;

	if (element_has_animations)
		stylesheet = GetStyleSheet().get();

	if (!stylesheet) {
		return;
	}

	// Remove existing animations
	{
		auto it_remove = std::partition(animations.begin(), animations.end(), 
			[](const ElementAnimation & animation) { return animation.GetOrigin() != ElementAnimationOrigin::Animation; }
		);
		for (auto it = it_remove; it != animations.end(); ++it)
			it->Release(*this);
		animations.erase(it_remove, animations.end());
	}

	// Start animations
	for (const auto& animation : animation_list) {
		const Keyframes* keyframes_ptr = stylesheet->GetKeyframes(animation.name);
		if (keyframes_ptr && keyframes_ptr->blocks.size() >= 1 && !animation.paused) {
			auto& property_ids = keyframes_ptr->property_ids;
			auto& blocks = keyframes_ptr->blocks;
			bool has_from_key = (blocks[0].normalized_time == 0);
			bool has_to_key = (blocks.back().normalized_time == 1);
			// If the first key defines initial conditions for a given property, use those values, else, use this element's current values.
			for (PropertyId id : property_ids)
				StartAnimation(id, (has_from_key ? PropertyDictionaryGet(blocks[0].properties, id) : nullptr), animation.num_iterations, animation.alternate, animation.delay, true);
			// Add middle keys: Need to skip the first and last keys if they set the initial and end conditions, respectively.
			for (int i = (has_from_key ? 1 : 0); i < (int)blocks.size() + (has_to_key ? -1 : 0); i++) {
				// Add properties of current key to animation
				float time = blocks[i].normalized_time * animation.duration;
				for (auto& property : blocks[i].properties)
					AddAnimationKeyTime(property.first, &property.second, time, animation.tween);
			}
			// If the last key defines end conditions for a given property, use those values, else, use this element's current values.
			float time = animation.duration;
			for (PropertyId id : property_ids)
				AddAnimationKeyTime(id, (has_to_key ? PropertyDictionaryGet(blocks.back().properties, id) : nullptr), time, animation.tween);
		}
	}
}

void Element::AdvanceAnimations() {
	if (animations.empty()) {
		return;
	}
	double time = Time::Now();

	for (auto& animation : animations) {
		Property property = animation.UpdateAndGetProperty(time, *this);
		if (property.unit != Property::UNKNOWN)
			SetAnimationProperty(animation.GetPropertyId(), property);
	}

	// Move all completed animations to the end of the list
	auto it_completed = std::partition(animations.begin(), animations.end(), [](const ElementAnimation& animation) { return !animation.IsComplete(); });

	//std::vector<EventDictionary> dictionary_list;
	std::vector<bool> is_transition;
	//dictionary_list.reserve(animations.end() - it_completed);
	is_transition.reserve(animations.end() - it_completed);

	for (auto it = it_completed; it != animations.end(); ++it) {
		const std::string& property_name = StyleSheetSpecification::GetPropertyName(it->GetPropertyId());

		//dictionary_list.emplace_back();
		//dictionary_list.back().emplace("property", property_name);
		is_transition.push_back(it->IsTransition());

		it->Release(*this);
	}

	// Need to erase elements before submitting event, as iterators might be invalidated when calling external code.
	animations.erase(it_completed, animations.end());

	// TODO
	//for (size_t i = 0; i < dictionary_list.size(); i++)
	//	DispatchEvent(is_transition[i] ? "transitionend" : "animationend", dictionary_list[i], false, true);
}

void Element::DirtyPerspective() {
	dirty_perspective = true;
}

void Element::UpdateTransform() {
	if (!dirty_transform)
		return;
	dirty_transform = false;
	glm::mat4x4 new_transform(1);
	Point origin2d = metrics.frame.origin;
	if (parent) {
		origin2d = origin2d - parent->GetScrollOffset();
	}
	glm::vec3 origin(origin2d.x, origin2d.y, 0);
	auto computedTransform = GetComputedProperty(PropertyId::Transform)->GetTransformPtr();
	if (computedTransform && !computedTransform->empty()) {
		glm::vec3 transform_origin = origin + glm::vec3 {
			ComputePropertyW(GetComputedProperty(PropertyId::TransformOriginX), this),
			ComputePropertyH(GetComputedProperty(PropertyId::TransformOriginY), this),
			ComputeProperty (GetComputedProperty(PropertyId::TransformOriginZ), this),
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
	float distance = ComputeProperty(GetComputedProperty(PropertyId::Perspective), this);
	bool changed = false;
	if (distance > 0.0f) {
		glm::vec3 origin {
			ComputePropertyW(GetComputedProperty(PropertyId::PerspectiveOriginX), this),
			ComputePropertyH(GetComputedProperty(PropertyId::PerspectiveOriginY), this),
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

void Element::UpdateLayout() {
	if (layout.HasNewLayout() && Node::UpdateVisible()) {
		DirtyTransform();
		DirtyClip();
		dirty_background = true;
		dirty_image = true;
		Rect content {};
		for (auto& child : children) {
			child->UpdateLayout();
			if (child->IsVisible()) {
				content.Union(child->GetMetrics().content);
			}
		}
		Node::UpdateMetrics(content);
	}
}

Element* Element::ElementFromPoint(Point point) {
	if (!IsVisible()) {
		return nullptr;
	}
	bool overflowVisible = GetLayout().GetOverflow() == Layout::Overflow::Visible;
	if (!overflowVisible && !IsPointWithinElement(point)) {
		return nullptr;
	}
	UpdateStackingContext();
	for (auto iter = stacking_context.rbegin(); iter != stacking_context.rend();++iter) {
		Element* res = (*iter)->ElementFromPoint(point);
		if (res) {
			return res;
		}
	}
	if (overflowVisible && !IsPointWithinElement(point)) {
		return nullptr;
	}
	return this;
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
	Size size = GetMetrics().frame.size;
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
	if (layout.GetOverflow() != Layout::Overflow::Scroll) {
		return {0,0};
	}
	Size scrollOffset {
		GetComputedProperty(PropertyId::ScrollLeft)->GetFloat(),
		GetComputedProperty(PropertyId::ScrollTop)->GetFloat()
	};
	layout.UpdateScrollOffset(scrollOffset, metrics);
	return scrollOffset;
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

void Element::SetClassNames(const std::string& class_names) {
	classes.clear();
	StringUtilities::ExpandString(classes, class_names, ' ');
	DirtyDefinition();
}

std::string Element::GetClassNames() const {
	std::string class_names;
	for (size_t i = 0; i < classes.size(); i++) {
		if (i != 0) {
			class_names += " ";
		}
		class_names += classes[i];
	}
	return class_names;
}

void Element::DirtyPropertiesWithUnitRecursive(Property::Unit unit) {
	DirtyProperties(unit);
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
		return PropertyDictionaryGet(*definition_properties, id);
	return nullptr;
}

const Property* Element::GetProperty(const std::string& name) const {
	return GetProperty(StyleSheetSpecification::GetPropertyId(name));
}

const Property* Element::GetAnimationProperty(PropertyId id) const {
	return PropertyDictionaryGet(animation_properties, id);
}

const Property* Element::GetComputedProperty(PropertyId id) const {
	const Property* property = GetComputedLocalProperty(id);
	if (property)
		return property;
	const PropertyDefinition* propertyDef = StyleSheetSpecification::GetProperty(id);
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
	return propertyDef->GetDefaultValue();
}

const Property* Element::GetTransitionProperty(const PropertyDictionary* def) const {
	const Property* property = PropertyDictionaryGet(inline_properties, PropertyId::Transition);
	if (property)
		return property;
	if (def)
		return PropertyDictionaryGet(*def, PropertyId::Transition);
	return nullptr;
}

void Element::TransitionPropertyChanges(PropertyIdSet& properties, const PropertyDictionary* new_definition) {
	const Property* transition_property = GetTransitionProperty(new_definition);
	if (!transition_property) {
		return;
	}
	auto transition_list = transition_property->GetTransitionList();
	if (transition_list.none) {
		return;
	}
	auto add_transition = [&](const Transition& transition) {
		const Property* from = GetComputedProperty(transition.id);
		const Property* to = PropertyDictionaryGet(*new_definition, transition.id);
		if (from && to && (from->unit == to->unit) && (*from != *to)) {
			return StartTransition(transition, *from, *to);
		}
		return false;
	};
	if (transition_list.all) {
		Transition transition = transition_list.transitions[0];
		for (auto it = properties.begin(); it != properties.end(); ) {
			transition.id = *it;
			if (add_transition(transition))
				it = properties.Erase(it);
			else
				++it;
		}
	}
	else {
		for (auto& transition : transition_list.transitions) {
			if (properties.Contains(transition.id)) {
				if (add_transition(transition))
					properties.Erase(transition.id);
			}
		}
	}
}

void Element::TransitionPropertyChanges(PropertyId id, const Property& property) {
	const Property* transition_property = GetTransitionProperty(definition_properties.get());
	if (!transition_property) {
		return;
	}
	auto transition_list = transition_property->GetTransitionList();
	if (transition_list.none) {
		return;
	}
	auto add_transition = [&](const Transition& transition) {
		const Property* from = GetComputedProperty(id);
		if (from && (from->unit == property.unit) && (*from != property)) {
			StartTransition(transition, *from, property);
		}
	};
	if (transition_list.all) {
		Transition transition = transition_list.transitions[0];
		transition.id = id;
		add_transition(transition);
	}
	else {
		for (auto& transition : transition_list.transitions) {
			if (transition.id == id) {
				add_transition(transition);
			}
		}
	}
}

void Element::UpdateDefinition() {
	if (!dirty_definition) {
		return;
	}
	dirty_definition = false;
	std::shared_ptr<PropertyDictionary> new_definition;
	if (auto& style_sheet = GetStyleSheet()) {
		new_definition = style_sheet->GetElementDefinition(this);
	}
	if (new_definition != definition_properties) {
		if (definition_properties && new_definition) {
			PropertyIdSet changed_properties = PropertyDictionaryDiff(*definition_properties, *new_definition);
			for (PropertyId id : changed_properties) {
				if (PropertyDictionaryGet(inline_properties, id)) {
					changed_properties.Erase(id);
				}
			}
			if (!changed_properties.Empty()) {
				TransitionPropertyChanges(changed_properties, new_definition.get());
			}
			definition_properties = new_definition;
			DirtyProperties(changed_properties);
		}
		else if (definition_properties) {
			PropertyIdSet changed_properties = PropertyDictionaryGetIds(*definition_properties);
			definition_properties = new_definition;
			DirtyProperties(changed_properties);
		}
		else if (new_definition) {
			PropertyIdSet changed_properties = PropertyDictionaryGetIds(*new_definition);
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

bool Element::SetProperty(PropertyId id, const Property& property) {
	Property new_property = property;
	new_property.definition = StyleSheetSpecification::GetProperty(id);
	if (!new_property.definition) {
		return false;
	}
	TransitionPropertyChanges(id, new_property);
	inline_properties[id] = new_property;
	DirtyProperty(id);
	return true;
}

bool Element::SetAnimationProperty(PropertyId id, const Property& property) {
	Property new_property = property;
	new_property.definition = StyleSheetSpecification::GetProperty(id);
	if (!new_property.definition)
		return false;
	animation_properties[id] = new_property;
	DirtyProperty(id);
	return true;
}

bool Element::SetPropertyImmediate(PropertyId id, const Property& property) {
	Property new_property = property;
	new_property.definition = StyleSheetSpecification::GetProperty(id);
	if (!new_property.definition)
		return false;
	inline_properties[id] = new_property;
	DirtyProperty(id);
	return true;
}

void Element::RemoveProperty(PropertyId id) {
	//TODO 需要触发动画
	if (inline_properties.erase(id)) {
		DirtyProperty(id);
	}
}

void Element::RemoveAnimationProperty(PropertyId id) {
	if (animation_properties.erase(id)) {
		DirtyProperty(id);
	}
}

void Element::DirtyDefinition() {
	dirty_definition = true;
}

void Element::DirtyInheritedProperties() {
	dirty_properties |= StyleSheetSpecification::GetRegisteredInheritedProperties();
}

void Element::DirtyProperties(Property::Unit unit) {
	ForeachProperties([&](PropertyId id, const Property& property){
		if (property.unit & unit) {
			DirtyProperty(id);
		}
	});
}

void Element::ForeachProperties(std::function<void(PropertyId id, const Property& property)> f) {
	PropertyIdSet mark;
	for (auto& [id, property] : inline_properties) {
		mark.Insert(id);
		f(id, property);
	}
	if (definition_properties) {
		for (auto& [id, property] : *definition_properties) {
			if (!mark.Contains(id)) {
				f(id, property);
			}
		}
	}
}

void Element::DirtyProperty(PropertyId id) {
	dirty_properties.Insert(id);
}

void Element::DirtyProperties(const PropertyIdSet& properties) {
	dirty_properties |= properties;
}

void Element::UpdateProperties() {
	UpdateDefinition();
	if (dirty_properties.Empty()) {
		return;
	}

	bool dirty_em_properties = false;
	if (dirty_properties.Contains(PropertyId::FontSize)) {
		if (UpdataFontSize()) {
			dirty_em_properties = true;
			dirty_properties.Insert(PropertyId::LineHeight);
		}
	}

	ForeachProperties([&](PropertyId id, const Property& property){
		if (dirty_em_properties && property.unit == Property::EM)
			dirty_properties.Insert(id);
		if (!dirty_properties.Contains(id)) {
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
		case PropertyId::BorderTopColor:
			computed_values.border_color.top = property.GetColor();
			break;
		case PropertyId::BorderRightColor:
			computed_values.border_color.right = property.GetColor();
			break;
		case PropertyId::BorderBottomColor:
			computed_values.border_color.bottom = property.GetColor();
			break;
		case PropertyId::BorderLeftColor:
			computed_values.border_color.left = property.GetColor();
			break;
		case PropertyId::BorderTopLeftRadius:
			computed_values.border_radius.topLeft = property.ToFloatValue();
			break;
		case PropertyId::BorderTopRightRadius:
			computed_values.border_radius.topRight = property.ToFloatValue();
			break;
		case PropertyId::BorderBottomRightRadius:
			computed_values.border_radius.bottomRight = property.ToFloatValue();
			break;
		case PropertyId::BorderBottomLeftRadius:
			computed_values.border_radius.bottomLeft = property.ToFloatValue();
			break;
		case PropertyId::BackgroundColor:
			computed_values.background_color = property.GetColor();
			break;
		case PropertyId::Transition:
			computed_values.transition = property.GetTransitionList();
			break;
		case PropertyId::Animation:
			computed_values.animation = property.GetAnimationList();
			break;
		default:
			break;
		}
	});

	// Next, pass inheritable dirty properties onto our children
	PropertyIdSet dirty_inherited_properties = (dirty_properties & StyleSheetSpecification::GetRegisteredInheritedProperties());
	if (!dirty_inherited_properties.Empty()) {
		for (auto& child : children) {
			child->DirtyProperties(dirty_inherited_properties);
		}
	}

	if (!dirty_properties.Empty()) {
		OnChange(dirty_properties);
		dirty_properties.Clear();
	}
}

}
