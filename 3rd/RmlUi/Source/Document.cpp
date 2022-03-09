/*
 * This source file is part of RmlUi, the HTML/CSS Interface Middleware
 *
 * For the latest information, see http://github.com/mikke89/RmlUi
 *
 * Copyright (c) 2008-2010 CodePoint Ltd, Shift Technology Ltd
 * Copyright (c) 2019 The RmlUi Team, and contributors
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/DataModelHandle.h"
#include "../Include/RmlUi/FileInterface.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/Log.h"
#include "ElementStyle.h"
#include "EventDispatcher.h"
#include "StyleSheetFactory.h"
#include "DataModel.h"
#include "PluginRegistry.h"
#include "HtmlParser.h"
#include <set>
#include <fstream>

namespace Rml {

Document::Document(const Size& _dimensions)
	: body(new ElementDocument(this))
	, dimensions(_dimensions)
{
	style_sheet = nullptr;
	PluginRegistry::NotifyDocumentCreate(this);
}

Document::~Document() {
	body->RemoveAllEvents();
	PluginRegistry::NotifyDocumentDestroy(this);
	body.reset();
}


using namespace std::literals;

static bool isDataViewElement(Element* e) {
	for (const std::string& name : Factory::GetStructuralDataViewAttributeNames()) {
		if (e->GetTagName() == name) {
			return true;
		}
	}
	return false;
}

class DocumentHtmlHandler: public HtmlHandler {
	Document&             m_doc;
	ElementAttributes     m_attributes;
	std::shared_ptr<StyleSheet> m_style_sheet;
	std::stack<Element*>  m_stack;
	Element*              m_parent = nullptr;
	Element*              m_current = nullptr;
	size_t                m_line = 0;
	bool				  m_inner_xml = false;

public:
	DocumentHtmlHandler(Document& doc)
		: m_doc(doc)
	{}
	void OnInnerXML(bool inner) override { m_inner_xml = inner; }
	void OnDocumentBegin() override {}
	void OnDocumentEnd() override {
		if (m_style_sheet) {
			m_doc.SetStyleSheet(std::move(m_style_sheet));
		}
	}
	void OnElementBegin(const char* szName) override {
		if (m_inner_xml) {
			return;
		}
		m_attributes.clear();

		if (!m_current && szName == "body"sv) {
			m_current = m_doc.body.get();
			return;
		}
		if (!m_current) {
			return;
		}
		m_stack.push(m_current);
		m_parent = m_current;
		m_current = new Element(&m_doc, szName);
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
		if (szName == "script"sv) {
			auto it = m_attributes.find("path");
			if (it != m_attributes.end()) {
				m_doc.LoadExternalScript(it->second);
			}
		}
		else if (szName == "style"sv) {
			auto it = m_attributes.find("path");
			if (it != m_attributes.end()) {
				LoadExternalStyle(it->second);
			}
		}
		else {
			OnElementEnd(szName, {});
		}
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
	void OnTextBegin() override {}
	void OnTextEnd(const char* szValue) override {
		if (m_inner_xml) {
			return;
		}
		if (m_current) {
			if (isDataViewElement(m_current) && ElementUtilities::ApplyStructuralDataViews(m_current, szValue)) {
				return;
			}
			Factory::InstanceElementText(m_current, szValue);
		}
	}
	void OnComment(const char* szText) override {}
	void OnScriptBegin(unsigned int line) override {
		m_line = line;
	}
	void OnScriptEnd(const char* szValue) override {
		auto it = m_attributes.find("path");
		if (it == m_attributes.end()) {
			m_doc.LoadInlineScript(szValue, m_doc.GetSourceURL(), m_line);
		}
		else {
			m_doc.LoadExternalScript(it->second);
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
				std::shared_ptr<StyleSheet> combined_sheet = m_style_sheet->CombineStyleSheet(*inline_sheet);
				m_style_sheet = combined_sheet;
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
				std::shared_ptr<StyleSheet> combined_sheet = m_style_sheet->CombineStyleSheet(*sub_sheet);
				m_style_sheet = std::move(combined_sheet);
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
			LoadInlineStyle(szValue, m_doc.GetSourceURL(), m_line);
		}
		else {
			LoadExternalStyle(it->second);
		}
	}
};

bool Document::Load(const std::string& path) {
	try {
		std::ifstream input(GetFileInterface()->GetPath(path));
		if (!input) {
			return false;
		}
		std::string data((std::istreambuf_iterator<char>(input)), std::istreambuf_iterator<char>());
		input.close();

		source_url = path;
		HtmlParser parser;
		DocumentHtmlHandler handler(*this);
		parser.Parse(data, &handler);
		body->UpdateProperties();
		UpdateDataModel(false);
		Update();
	}
	catch (HtmlParserException& e) {
		Log::Message(Log::Level::Error, "%s Line: %d Column: %d", e.what(), e.GetLine(), e.GetColumn());
		return false;
	}
	return true;
}

const std::string& Document::GetSourceURL() const
{
	return source_url;
}

// Sets the style sheet this document, and all of its children, uses.
void Document::SetStyleSheet(std::shared_ptr<StyleSheet> _style_sheet)
{
	if (style_sheet == _style_sheet)
		return;

	style_sheet = std::move(_style_sheet);
	
	if (style_sheet)
	{
		style_sheet->BuildNodeIndex();
	}

	body->GetStyle()->DirtyDefinition();
}

// Returns the document's style sheet.
const std::shared_ptr<StyleSheet>& Document::GetStyleSheet() const
{
	return style_sheet;
}

ElementPtr Document::CreateElement(const std::string& name)
{
	ElementPtr element(new Element(this, name));
	return element;
}

// Create a text element.
TextPtr Document::CreateTextNode(const std::string& str)
{
	TextPtr text(new ElementText(this, str));
	if (!text)
	{
		Log::Message(Log::Level::Error, "Failed to create text element, instancer didn't return a derivative of ElementText.");
		return nullptr;
	}
	return text;
}

// Default load inline script implementation
void Document::LoadInlineScript(const std::string& content, const std::string& source_path, int source_line)
{
	PluginRegistry::NotifyLoadInlineScript(this, content, source_path, source_line);
}

// Default load external script implementation
void Document::LoadExternalScript(const std::string& source_path)
{
	PluginRegistry::NotifyLoadExternalScript(this, source_path);
}

void Document::UpdateDataModel(bool clear_dirty_variables) {
	for (auto& data_model : data_models) {
		data_model.second->Update(clear_dirty_variables);
	}
}

using ElementSet = std::set<Element*>;

using ElementObserverList = std::vector< ObserverPtr<Element> >;

class ElementObserverListBackInserter {
public:
	using iterator_category = std::output_iterator_tag;
	using value_type = void;
	using difference_type = void;
	using pointer = void;
	using reference = void;
	using container_type = ElementObserverList;

	ElementObserverListBackInserter(ElementObserverList& elements) : elements(&elements) {}
	ElementObserverListBackInserter& operator=(Element* element) {
		elements->push_back(element->GetObserverPtr());
		return *this;
	}
	ElementObserverListBackInserter& operator*() { return *this; }
	ElementObserverListBackInserter& operator++() { return *this; }
	ElementObserverListBackInserter& operator++(int) { return *this; }

private:
	ElementObserverList* elements;
};

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
		body->GetStyle()->DirtyPropertiesWithUnitRecursive(Property::VIEW_LENGTH);
	}
}

const Size& Document::GetDimensions() {
	return dimensions;
}

void Document::Update() {
	UpdateDataModel(true);
	body->Update();
	if (dirty_dimensions || body->GetLayout().IsDirty()) {
		dirty_dimensions = false;
		body->GetLayout().CalculateLayout(dimensions);
	}
	body->UpdateLayout();
	body->Render();
}

Element* Document::ElementFromPoint(Point pt) const {
	return body->ElementFromPoint(pt);
}

} // namespace Rml
