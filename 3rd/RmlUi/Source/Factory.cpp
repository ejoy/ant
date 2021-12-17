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

#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Document.h"
#include "../Include/RmlUi/Stream.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/ElementText.h"
#include "../Include/RmlUi/ElementUtilities.h"
#include "../Include/RmlUi/EventListenerInstancer.h"
#include "../Include/RmlUi/StyleSheet.h"
#include "../Include/RmlUi/StringUtilities.h"
#include "../Include/RmlUi/Log.h"
#include "DataControllerDefault.h"
#include "DataViewDefault.h"
#include "PluginRegistry.h"
#include "PropertyParserColour.h"
#include "StyleSheetFactory.h"
#include "HtmlParser.h"

#include <algorithm>

namespace Rml {

// Data view instancers.
using DataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;
static DataViewInstancerMap data_view_instancers;

// Data controller instancers.
using DataControllerInstancerMap = std::unordered_map< std::string, DataControllerInstancer* >;
static DataControllerInstancerMap data_controller_instancers;

// Structural data view instancers.
using StructuralDataViewInstancerMap = std::unordered_map< std::string, DataViewInstancer* >;
static StructuralDataViewInstancerMap structural_data_view_instancers;

// Structural data view names.
static std::vector<std::string> structural_data_view_attribute_names;

// Event listener instancer.
static EventListenerInstancer* event_listener_instancer = nullptr;

// Default instancers are constructed and destroyed on Initialise and Shutdown, respectively.
struct DefaultInstancers {
	// Data binding views
	DataViewInstancerDefault<DataViewAttribute> data_view_attribute;
	DataViewInstancerDefault<DataViewAttributeIf> data_view_attribute_if;
	DataViewInstancerDefault<DataViewClass> data_view_class;
	DataViewInstancerDefault<DataViewIf> data_view_if;
	DataViewInstancerDefault<DataViewVisible> data_view_visible;
	DataViewInstancerDefault<DataViewRml> data_view_rml;
	DataViewInstancerDefault<DataViewStyle> data_view_style;
	DataViewInstancerDefault<DataViewText> data_view_text;
	DataViewInstancerDefault<DataViewValue> data_view_value;

	DataViewInstancerDefault<DataViewFor> structural_data_view_for;

	// Data binding controllers
	DataControllerInstancerDefault<DataControllerValue> data_controller_value;
	DataControllerInstancerDefault<DataControllerEvent> data_controller_event;
};

static std::unique_ptr<DefaultInstancers> default_instancers;


Factory::Factory()
{
}

Factory::~Factory()
{
}


bool Factory::Initialise()
{
	default_instancers = std::make_unique<DefaultInstancers>();

	// No default event listener instancer
	if (!event_listener_instancer)
		event_listener_instancer = nullptr;

	// Data binding views
	RegisterDataViewInstancer(&default_instancers->data_view_attribute,      "attr",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_attribute_if,   "attrif",  false);
	RegisterDataViewInstancer(&default_instancers->data_view_class,          "class",   false);
	RegisterDataViewInstancer(&default_instancers->data_view_if,             "if",      false);
	RegisterDataViewInstancer(&default_instancers->data_view_visible,        "visible", false);
	RegisterDataViewInstancer(&default_instancers->data_view_rml,            "rml",     false);
	RegisterDataViewInstancer(&default_instancers->data_view_style,          "style",   false);
	RegisterDataViewInstancer(&default_instancers->data_view_text,           "text",    false);
	RegisterDataViewInstancer(&default_instancers->data_view_value,          "value",   false);
	RegisterDataViewInstancer(&default_instancers->structural_data_view_for, "for",     true );

	// Data binding controllers
	RegisterDataControllerInstancer(&default_instancers->data_controller_value, "value");
	RegisterDataControllerInstancer(&default_instancers->data_controller_event, "event");

	return true;
}

void Factory::Shutdown()
{
	data_controller_instancers.clear();
	data_view_instancers.clear();
	structural_data_view_instancers.clear();
	structural_data_view_attribute_names.clear();

	event_listener_instancer = nullptr;

	default_instancers.reset();
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
public:
	EmbedHtmlHandler(Element* current)
		: m_current{ current }
	{
		m_doc = m_current->GetOwnerDocument();
	}
	bool IsEmbed() override { return true; }
	void OnDocumentEnd() override {
		if (m_style_sheet) {
			m_doc->SetStyleSheet(std::move(m_style_sheet));
		}
	}
	void OnElementBegin(const char* szName) override {
		m_attributes.clear();
		if (!m_current) {
			return;
		}
		m_stack.push(m_current);
		m_parent = m_current;
		m_current = new Element(m_doc, szName);
	}
	void OnElementClose() override {
		if (m_parent && m_current) {
			m_parent->AppendChild(ElementPtr(m_current));
		}
	}
	void OnElementEnd(const  char* szName, const std::string& inner_xml_data) override {
		if (!m_current) {
			return;
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
		if (m_current) {
			m_current->SetAttribute(szName, szValue);
		}
		else {
			m_attributes.emplace(szName, szValue);
		}
	}
	void OnTextEnd(const char* szValue) override {
		if (m_current) {
			if (isDataViewElement(m_current) && ElementUtilities::ApplyStructuralDataViews(m_current, szValue)) {
				return;
			}
			Factory::InstanceElementText(m_current, szValue);
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
			LoadInlineStyle(szValue, m_doc->GetSourceURL(), m_line);
		}
		else {
			LoadExternalStyle(it->second);
		}
	}
};

// Instances a single text element containing a string.
bool Factory::InstanceElementText(Element* parent, const std::string& str)
{
	RMLUI_ASSERT(parent);

	if (std::all_of(str.begin(), str.end(), &StringUtilities::IsWhitespace))
		return true;

	// See if we need to parse it as RML, and whether the text contains data expressions (curly brackets).
	bool parse_as_rml = false;
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
		else if (c == '<') {
			parse_as_rml = true;
			break;
		}
		previous = c;
	}

	if (parse_as_rml) {
// 		Context* context = parent->GetContext();
// 		std::string tag = context ? context->GetDocumentsBaseTag() : "body";

// 		std::string tag = "body";
// 		std::string data = "<body>\n";
// 		data += str;
// 		std::string close_tag = "\n</body>";
		HtmlParser parser;
		EmbedHtmlHandler handler(parent);
		parser.Parse(str, &handler);
	}
	else {
		TextPtr text(new ElementText(parent->GetOwnerDocument(), str));
		if (!text) {
			Log::Message(Log::Level::Error, "Failed to instance text element '%s', instancer returned nullptr.", str.c_str());
			return false;
		}
		if (has_data_expression) {
			ElementAttributes attributes;
			attributes.emplace("data-text", std::string());
			text->SetAttributes(attributes);
		}
		parent->AppendChild(std::move(text));
	}
	
	return true;
}

// Register an instancer for all event listeners
void Factory::RegisterEventListenerInstancer(EventListenerInstancer* instancer)
{
	event_listener_instancer = instancer;
}

// Instance an event listener with the given string
EventListener* Factory::InstanceEventListener(Element* element, const std::string& type, const std::string& code, bool use_capture)
{
	// If we have an event listener instancer, use it
	if (event_listener_instancer)
		return event_listener_instancer->InstanceEventListener(element, type, code, use_capture);

	return nullptr;
}

void Factory::RegisterDataViewInstancer(DataViewInstancer* instancer, const std::string& name, bool is_structural_view)
{
	bool inserted = false;
	if (is_structural_view)
	{
		inserted = structural_data_view_instancers.emplace(name, instancer).second;
		if (inserted)
			structural_data_view_attribute_names.push_back(std::string("data-") + name);
	}
	else
	{
		inserted = data_view_instancers.emplace(name, instancer).second;
	}
	
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data view instancer '%s'. The given name is already registered.", name.c_str());
}

void Factory::RegisterDataControllerInstancer(DataControllerInstancer* instancer, const std::string& name)
{
	bool inserted = data_controller_instancers.emplace(name, instancer).second;
	if (!inserted)
		Log::Message(Log::Level::Warning, "Could not register data controller instancer '%s'. The given name is already registered.", name.c_str());
}

DataViewPtr Factory::InstanceDataView(const std::string& type_name, Element* element, bool is_structural_view)
{
	RMLUI_ASSERT(element);

	if (is_structural_view)
	{
		auto it = structural_data_view_instancers.find(type_name);
		if (it != structural_data_view_instancers.end())
			return it->second->InstanceView(element);
	}
	else
	{
		auto it = data_view_instancers.find(type_name);
		if (it != data_view_instancers.end())
			return it->second->InstanceView(element);
	}
	return nullptr;
}

DataControllerPtr Factory::InstanceDataController(Element* element, const std::string& type_name)
{
	auto it = data_controller_instancers.find(type_name);
	if (it != data_controller_instancers.end())
		return it->second->InstanceController(element);
	return DataControllerPtr();
}

bool Factory::IsStructuralDataView(const std::string& type_name)
{
	return structural_data_view_instancers.find(type_name) != structural_data_view_instancers.end();
}

const std::vector<std::string>& Factory::GetStructuralDataViewAttributeNames()
{
	return structural_data_view_attribute_names;
}

} // namespace Rml
