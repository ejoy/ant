#include <core/Document.h>
#include <binding/Context.h>
#include <core/Interface.h>
#include <css/StyleSheet.h>
#include <css/StyleSheetParser.h>
#include <core/Text.h>
#include <util/HtmlParser.h>

namespace Rml {

Document::Document(const Size& _dimensions)
	: body(this, "body")
	, dimensions(_dimensions)
{ }

Document::~Document() {
	body.RemoveAllChildren();
}

void Document::InstanceHead(const HtmlElement& html, std::function<void(HtmlHead, const std::string&, int)> func) {
	assert(html.children.size() == 1);
	auto const& rootHtml = std::get<HtmlElement>(html.children[0]);
	assert(rootHtml.children.size() == 2);
	auto const& headHtml = std::get<HtmlElement>(rootHtml.children[0]);
	for (auto const& node : headHtml.children) {
		auto element = std::get_if<HtmlElement>(&node);
		if (element) {
			if (element->tag == "script") {
				if (element->children.size() > 0) {
					auto& content = std::get<HtmlString>(element->children[0]);
					auto source_line = std::get<0>(element->position);
					func(HtmlHead::Script, content, source_line);
				}
				else {
					auto it = element->attributes.find("path");
					if (it != element->attributes.end()) {
						auto& source_path = it->second;
						func(HtmlHead::Script, source_path, -1);
					}
				}
			}
			else if (element->tag == "style") {
				if (element->children.size() > 0) {
					auto& content = std::get<HtmlString>(element->children[0]);
					auto source_line = std::get<0>(element->position);
					func(HtmlHead::Style, content, source_line);
				}
				else {
					auto it = element->attributes.find("path");
					if (it != element->attributes.end()) {
						auto& source_path = it->second;
						func(HtmlHead::Style, source_path, -1);
					}
				}
			}
		}
	}
}

void Document::InstanceBody(const HtmlElement& html) {
	assert(html.children.size() == 1);
	auto const& rootHtml = std::get<HtmlElement>(html.children[0]);
	assert(rootHtml.children.size() == 2);
	auto const& bodyHtml = std::get<HtmlElement>(rootHtml.children[1]);
	style_sheet.Sort();
	body.InstanceOuter(bodyHtml);
	body.NotifyCreated();
	body.InstanceInner(bodyHtml);
	body.DirtyDefinition();
}

const StyleSheet& Document::GetStyleSheet() const {
	return style_sheet;
}

void Document::SetDimensions(const Size& _dimensions) {
	if (dimensions != _dimensions) {
		dirty_dimensions = true;
		dimensions = _dimensions;
		body.DirtyPropertiesWithUnitRecursive(PropertyUnit::VW);
		body.DirtyPropertiesWithUnitRecursive(PropertyUnit::VH);
		body.DirtyPropertiesWithUnitRecursive(PropertyUnit::VMIN);
		body.DirtyPropertiesWithUnitRecursive(PropertyUnit::VMAX);
	}
}

const Size& Document::GetDimensions() {
	return dimensions;
}

void Document::Flush() {
	body.Update();
	UpdateLayout();
	body.UpdateRender();
}

void Document::Update(float delta) {
	body.Update();
	body.UpdateAnimations(delta);
	Style::Instance().Flush();//TODO
	UpdateLayout();
	body.Render();
	removednodes.clear();
}

void Document::UpdateLayout() {
	if (dirty_dimensions || body.GetLayout().IsDirty()) {
		dirty_dimensions = false;
		body.GetLayout().CalculateLayout(dimensions);
#if 0
		printf("%s\n", body.GetLayout().ToString().c_str());
#endif
	}
	body.UpdateLayout();
}

Element* Document::ElementFromPoint(Point pt) {
	return body.ElementFromPoint(pt);
}

Element* Document::GetBody() {
	return &body;
}

const Element* Document::GetBody() const {
	return &body;
}

Element* Document::CreateElement(const std::string& tag){
	return new Element(this, tag);
}

Text* Document::CreateTextNode(const std::string& str) {
	auto e = new Text(this, str);
	GetScript()->OnCreateText(this, e);
	return e;
}

RichText* Document::CreateRichTextNode(const std::string& str) {
	auto e = new RichText(this, str);
	GetScript()->OnCreateText(this, e);
	return e;
}

void Document::RecycleNode(std::unique_ptr<Node>&& node) {
	GetScript()->OnDestroyNode(this, node.get());
	removednodes.emplace_back(std::forward<std::unique_ptr<Node>>(node));
}

void Document::LoadStyleSheet(std::string_view source_path, std::string_view content) {
	ParseStyleSheet(style_sheet, source_path, content);
}

void Document::LoadStyleSheet(std::string_view source_path, std::string_view content, int source_line) {
	ParseStyleSheet(style_sheet, source_path, content, source_line);
}

}
