#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/DataUtilities.h"
#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "../Include/RmlUi/FileInterface.h"
#include "../Include/RmlUi/Log.h"
#include "../Include/RmlUi/Plugin.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "StyleSheetFactory.h"
#include "DataModel.h"
#include "HtmlParser.h"
#include <fstream>

namespace Rml {

Document::Document(const Size& _dimensions)
	: body(this)
	, dimensions(_dimensions)
{ }

Document::~Document() {
	body.RemoveAllEvents();
}

bool Document::Load(const std::string& path) {
	std::ifstream input(GetFileInterface()->GetPath(path));
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
		Log::Message(Log::Level::Error, "%s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		return false;
	}

	body.UpdateProperties();
	UpdateDataModel(false);
	body.Update();
	return true;
}

void Document::Instance(const HtmlElement& html) {
	assert(html.children.size() == 1);
	auto const& rootHtml = std::get<HtmlElement>(html.children[0]);
	assert(rootHtml.children.size() == 2);
	auto const& headHtml = std::get<HtmlElement>(rootHtml.children[0]);
	auto const& bodyHtml = std::get<HtmlElement>(rootHtml.children[1]);
	
	style_sheet.Reset();

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
	style_sheet.BuildNodeIndex();

	body.InstanceOuter(bodyHtml);
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

void Document::UpdateDataModel(bool clear_dirty_variables) {
	for (auto& data_model : data_models) {
		data_model.second->Update(clear_dirty_variables);
	}
}

DataModelConstructor Document::CreateDataModel(const std::string& name) {
	auto result = data_models.emplace(name, std::make_unique<DataModel>());
	bool inserted = result.second;
	if (inserted)
		return DataModelConstructor(result.first->second.get());

	Log::Message(Log::Level::Error, "Data model name '%s' already exists.", name.c_str());
	return DataModelConstructor();
}

DataModelConstructor Document::GetDataModel(const std::string& name) {
	if (DataModel* model = GetDataModelPtr(name))
		return DataModelConstructor(model);
	Log::Message(Log::Level::Error, "Data model name '%s' could not be found.", name.c_str());
	return DataModelConstructor();
}

bool Document::RemoveDataModel(const std::string& name) {
	auto it = data_models.find(name);
	if (it == data_models.end())
		return false;

	DataModel* model = it->second.get();
	ElementList elements = model->GetAttachedModelRootElements();

	for (Element* element : elements)
		element->SetDataModel(nullptr);

	data_models.erase(it);

	return true;
}

DataModel* Document::GetDataModelPtr(const std::string& name) const {
	auto it = data_models.find(name);
	if (it != data_models.end())
		return it->second.get();
	return nullptr;
}

void Document::SetDimensions(const Size& _dimensions) {
	if (dimensions != _dimensions) {
		dirty_dimensions = true;
		dimensions = _dimensions;
		body.DirtyPropertiesWithUnitRecursive(Property::UnitMark::ViewLength);
	}
}

const Size& Document::GetDimensions() {
	return dimensions;
}

void Document::Update(double delta) {
    elapsed_time += delta;
	UpdateDataModel(true);
	body.Update();
	body.UpdateAnimations();
	if (dirty_dimensions || body.GetLayout().IsDirty()) {
		dirty_dimensions = false;
		body.GetLayout().CalculateLayout(dimensions);
	}
	body.UpdateLayout();
	body.Render();
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

ElementPtr Document::CreateElement(const std::string& tag){
	return ElementPtr(new Element(this, tag));
}

void Document::NotifyCustomElement(Element* e){
	if (custom_element.find(e->GetTagName()) != custom_element.end()) {
		GetPlugin()->OnCreateElement(this, e, e->GetTagName());
	}
}

ElementPtr Document::CreateTextNode(const std::string& str) {
	if (std::all_of(str.begin(), str.end(), &StringUtilities::IsWhitespace))
		return nullptr;
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
	ElementPtr e(new ElementText(this, str));
	if (has_data_expression) {
		e->SetAttribute("data-text", std::string());
	}
	return e;
}

void Document::DefineCustomElement(const std::string& name) {
	custom_element.emplace(name);
}

double Document::GetCurrentTime() {
	return elapsed_time / 1000;
}

}
