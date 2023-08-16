#include <core/Document.h>
#include <core/Core.h>
#include <core/Interface.h>
#include <util/Log.h>
#include <util/Stream.h>
#include <css/StyleSheet.h>
#include <core/Text.h>
#include <css/StyleSheetFactory.h>
#include <util/HtmlParser.h>
#include <fstream>

namespace Rml {

Document::Document(const Size& _dimensions, const std::string& path)
	: body(this, "body")
	, dimensions(_dimensions)
	, source_url(path)
{ }

Document::~Document() {
	body.RemoveAllChildren();
}

void Document::InstanceHead(const HtmlElement& html, std::function<void(const std::string&, int)> func) {
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
					func(content, source_line);
				}
				else {
					auto it = element->attributes.find("path");
					if (it != element->attributes.end()) {
						auto& source_path = it->second;
						func(source_path, -1);
					}
				}
			}
			else if (element->tag == "style") {
				if (element->children.size() > 0) {
					auto& content = std::get<HtmlString>(element->children[0]);
					auto source_line = std::get<0>(element->position);
					StyleSheetFactory::CombineStyleSheet(style_sheet, content, GetSourceURL(), source_line);
				}
				else {
					auto it = element->attributes.find("path");
					if (it != element->attributes.end()) {
						auto& source_path = it->second;
						StyleSheetFactory::CombineStyleSheet(style_sheet, source_path);
					}
				}
			}
		}
	}
	style_sheet.Sort();
}

void Document::InstanceBody(const HtmlElement& html) {
	assert(html.children.size() == 1);
	auto const& rootHtml = std::get<HtmlElement>(html.children[0]);
	assert(rootHtml.children.size() == 2);
	auto const& bodyHtml = std::get<HtmlElement>(rootHtml.children[1]);
	body.InstanceOuter(bodyHtml);
	body.NotifyCreated();
	body.InstanceInner(bodyHtml);
	body.DirtyDefinition();
}

const std::string& Document::GetSourceURL() const {
	return source_url;
}

const StyleSheet& Document::GetStyleSheet() const {
	return style_sheet;
}

void Document::UpdateDataModel() {
	GetPlugin()->OnUpdateDataModel(this);
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
	UpdateDataModel();
	body.Update();
	UpdateLayout();
	body.UpdateRender();
}

void Document::Update(float delta) {
	removednodes.clear();
	UpdateDataModel();
	body.Update();
	body.UpdateAnimations(delta);
	Style::Instance().Flush();//TODO
	UpdateLayout();
	body.Render();
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
	GetPlugin()->OnCreateText(this, e);
	return e;
}

RichText* Document::CreateRichTextNode(const std::string& str) {
	auto e = new RichText(this, str);
	GetPlugin()->OnCreateText(this, e);
	return e;
}

void Document::RecycleNode(std::unique_ptr<Node>&& node) {
	GetPlugin()->OnDestroyNode(this, node.get());
	removednodes.emplace_back(std::forward<std::unique_ptr<Node>>(node));
}
}
