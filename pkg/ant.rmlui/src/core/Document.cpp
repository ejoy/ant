#include <core/Document.h>
#include <core/Core.h>
#include <core/Interface.h>
#include <core/Log.h>
#include <core/Stream.h>
#include <core/StyleSheet.h>
#include <core/Text.h>
#include <core/StyleSheetFactory.h>
#include <core/HtmlParser.h>
#include <fstream>

namespace Rml {

Document::Document(const Size& _dimensions)
	: body(this, "body")
	, dimensions(_dimensions)
{ }

Document::~Document() {
	body.RemoveAllEvents();
	body.RemoveAllChildren();
}

bool Document::Load(const std::string& path) {
	std::ifstream input(GetPlugin()->OnRealPath(path));
	if (!input) {
		return false;
	}
	std::string data((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
	input.close();
	source_url = path;

	try {
		HtmlParser parser;
		HtmlElement dom = parser.Parse(data, false);
		Instance(dom);
	}
	catch (HtmlParserException& e) {
		Log::Message(Log::Level::Error, "%s Parse error: %s Line: %d Column: %d", path.c_str(), e.what(), e.GetLine(), e.GetColumn());
		return false;
	}

	Flush();
	return true;
}

void Document::Instance(const HtmlElement& html) {
	assert(html.children.size() == 1);
	auto const& rootHtml = std::get<HtmlElement>(html.children[0]);
	assert(rootHtml.children.size() == 2);
	auto const& headHtml = std::get<HtmlElement>(rootHtml.children[0]);
	auto const& bodyHtml = std::get<HtmlElement>(rootHtml.children[1]);
	
	for (auto const& node : headHtml.children) {
		auto element = std::get_if<HtmlElement>(&node);
		if (element) {
			if (element->tag == "script") {
				if (element->children.size() > 0) {
					LoadInlineScript(std::get<HtmlString>(element->children[0]), std::get<0>(element->position));
				}
				else {
					auto it = element->attributes.find("path");
					if (it != element->attributes.end()) {
						LoadExternalScript(it->second);
					}
				}
			}
			else if (element->tag == "style") {
				if (element->children.size() > 0) {
					LoadInlineStyle(std::get<HtmlString>(element->children[0]), std::get<0>(element->position));
				}
				else {
					auto it = element->attributes.find("path");
					if (it != element->attributes.end()) {
						LoadExternalStyle(it->second);
					}
				}
			}
		}
	}
	style_sheet.Sort();
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

void Document::LoadInlineScript(const std::string& content, int source_line) {
	GetPlugin()->OnLoadInlineScript(this, content, GetSourceURL(), source_line);
}

void Document::LoadExternalScript(const std::string& source_path) {
	GetPlugin()->OnLoadExternalScript(this, source_path);
}

void Document::LoadInlineStyle(const std::string& content, int source_line) {
	StyleSheetFactory::CombineStyleSheet(style_sheet, content, GetSourceURL(), source_line);
}

void Document::LoadExternalStyle(const std::string& source_path) {
	StyleSheetFactory::CombineStyleSheet(style_sheet, source_path);
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
