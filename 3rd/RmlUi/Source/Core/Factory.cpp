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

#include "../../Include/RmlUi/Core/Factory.h"
#include "../../Include/RmlUi/Core/Context.h"
#include "../../Include/RmlUi/Core/Core.h"
#include "../../Include/RmlUi/Core/ElementDocument.h"
#include "../../Include/RmlUi/Core/ElementText.h"
#include "../../Include/RmlUi/Core/ElementUtilities.h"
#include "../../Include/RmlUi/Core/EventListenerInstancer.h"
#include "../../Include/RmlUi/Core/StreamMemory.h"
#include "../../Include/RmlUi/Core/StyleSheet.h"
#include "../../Include/RmlUi/Core/SystemInterface.h"

#include "DataControllerDefault.h"
#include "DataViewDefault.h"
#include "EventInstancerDefault.h"
#include "FontEffectBlur.h"
#include "FontEffectGlow.h"
#include "FontEffectOutline.h"
#include "FontEffectShadow.h"
#include "PluginRegistry.h"
#include "PropertyParserColour.h"
#include "StreamFile.h"
#include "StyleSheetFactory.h"
#include "TemplateCache.h"
#include "XMLNodeHandlerBody.h"
#include "XMLNodeHandlerDefault.h"
#include "XMLNodeHandlerHead.h"
#include "XMLNodeHandlerTemplate.h"
#include "XMLParseTools.h"

#include <algorithm>

namespace Rml {

// Font effect instancers.
using FontEffectInstancerMap = UnorderedMap< String, FontEffectInstancer* >;
static FontEffectInstancerMap font_effect_instancers;

// Data view instancers.
using DataViewInstancerMap = UnorderedMap< String, DataViewInstancer* >;
static DataViewInstancerMap data_view_instancers;

// Data controller instancers.
using DataControllerInstancerMap = UnorderedMap< String, DataControllerInstancer* >;
static DataControllerInstancerMap data_controller_instancers;

// Structural data view instancers.
using StructuralDataViewInstancerMap = SmallUnorderedMap< String, DataViewInstancer* >;
static StructuralDataViewInstancerMap structural_data_view_instancers;

// Structural data view names.
static StringList structural_data_view_attribute_names;

// The event instancer
static EventInstancer* event_instancer = nullptr;

// Event listener instancer.
static EventListenerInstancer* event_listener_instancer = nullptr;

// Default instancers are constructed and destroyed on Initialise and Shutdown, respectively.
struct DefaultInstancers {

	UniquePtr<EventInstancer> event_default;

	// Font effects
	FontEffectBlurInstancer font_effect_blur;
	FontEffectGlowInstancer font_effect_glow;
	FontEffectOutlineInstancer font_effect_outline;
	FontEffectShadowInstancer font_effect_shadow;

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

static UniquePtr<DefaultInstancers> default_instancers;


Factory::Factory()
{
}

Factory::~Factory()
{
}


bool Factory::Initialise()
{
	default_instancers = MakeUnique<DefaultInstancers>();

	// Default event instancer
	if (!event_instancer)
	{
		default_instancers->event_default = MakeUnique<EventInstancerDefault>();
		event_instancer = default_instancers->event_default.get();
	}

	// No default event listener instancer
	if (!event_listener_instancer)
		event_listener_instancer = nullptr;

	// Font effect instancers
	RegisterFontEffectInstancer("blur", &default_instancers->font_effect_blur);
	RegisterFontEffectInstancer("glow", &default_instancers->font_effect_glow);
	RegisterFontEffectInstancer("outline", &default_instancers->font_effect_outline);
	RegisterFontEffectInstancer("shadow", &default_instancers->font_effect_shadow);

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

	// XML node handlers
	XMLParser::RegisterNodeHandler("", MakeShared<XMLNodeHandlerDefault>());
	XMLParser::RegisterNodeHandler("body", MakeShared<XMLNodeHandlerBody>());
	XMLParser::RegisterNodeHandler("head", MakeShared<XMLNodeHandlerHead>());
	XMLParser::RegisterNodeHandler("template", MakeShared<XMLNodeHandlerTemplate>());

	return true;
}

void Factory::Shutdown()
{
	font_effect_instancers.clear();

	data_controller_instancers.clear();
	data_view_instancers.clear();
	structural_data_view_instancers.clear();
	structural_data_view_attribute_names.clear();

	event_listener_instancer = nullptr;

	event_instancer = nullptr;

	XMLParser::ReleaseHandlers();

	default_instancers.reset();
}

ElementPtr Factory::InstanceElement(ElementDocument* document, const String& instancer_name, const String& tag, const XMLAttributes& attributes) {
	ElementPtr element(instancer_name == "body" ? new ElementDocument(tag) : new Element(tag));
	if (document) {
		element->SetOwnerDocument(document);
	}
	element->SetAttributes(attributes);
	return element;
}

// Instances a single text element containing a string.
bool Factory::InstanceElementText(Element* parent, const String& text)
{
	RMLUI_ASSERT(parent);

	// If this text node only contains white-space we don't want to construct it.
	const bool only_white_space = std::all_of(text.begin(), text.end(), &StringUtilities::IsWhitespace);
	if (only_white_space)
		return true;

	// See if we need to parse it as RML, and whether the text contains data expressions (curly brackets).
	bool parse_as_rml = false;
	bool has_data_expression = false;

	bool inside_brackets = false;
	char previous = 0;
	for (const char c : text)
	{
		const char* error_str = XMLParseTools::ParseDataBrackets(inside_brackets, c, previous);
		if (error_str)
		{
			Log::Message(Log::LT_WARNING, "Failed to instance text element '%s'. %s", text.c_str(), error_str);
			return false;
		}

		if (inside_brackets)
			has_data_expression = true;
		else if (c == '<')
			parse_as_rml = true;

		previous = c;
	}

	// If the text contains RML elements then run it through the XML parser again.
	if (parse_as_rml)
	{
		auto stream = MakeUnique<StreamMemory>(text.size() + 32);
		Context* context = parent->GetContext();
		String tag = "body";
		String open_tag = "<" + tag + ">";
		String close_tag = "</" + tag + ">";
		stream->Write(open_tag.c_str(), open_tag.size());
		stream->Write(text);
		stream->Write(close_tag.c_str(), close_tag.size());
		stream->Seek(0, SEEK_SET);

		XMLParser parser(parent);
		parser.Parse(stream.get());
	}
	else
	{		
		// Attempt to instance the element.
		XMLAttributes attributes;

		// If we have curly brackets in the text, we tag the element so that the appropriate data view (DataViewText) is constructed.
		if (has_data_expression)
			attributes.emplace("data-text", Variant());

		ElementPtr element(new ElementText("#text"));
		if (!element)
		{
			Log::Message(Log::LT_ERROR, "Failed to instance text element '%s', instancer returned nullptr.", text.c_str());
			return false;
		}
		element->SetOwnerDocument(parent->GetOwnerDocument());
		element->SetAttributes(attributes);

		// Assign the element its text value.
		ElementText* text_element = rmlui_dynamic_cast< ElementText* >(element.get());
		if (!text_element)
		{
			Log::Message(Log::LT_ERROR, "Failed to instance text element '%s'. Found type '%s', was expecting a derivative of ElementText.", text.c_str(), rmlui_type_name(*element));
			return false;
		}
		parent->AppendChild(std::move(element));
		text_element->SetText(text);
	}

	return true;
}

// Registers an instancer that will be used to instance font effects.
void Factory::RegisterFontEffectInstancer(const String& name, FontEffectInstancer* instancer)
{
	RMLUI_ASSERT(instancer);
	font_effect_instancers[StringUtilities::ToLower(name)] = instancer;
}

FontEffectInstancer* Factory::GetFontEffectInstancer(const String& name)
{
	auto iterator = font_effect_instancers.find(name);
	if (iterator == font_effect_instancers.end())
		return nullptr;

	return iterator->second;
}


// Creates a style sheet containing the passed in styles.
SharedPtr<StyleSheet> Factory::InstanceStyleSheetString(const String& string)
{
	auto memory_stream = MakeUnique<StreamMemory>((const byte*) string.c_str(), string.size());
	return InstanceStyleSheetStream(memory_stream.get());
}

// Creates a style sheet from a file.
SharedPtr<StyleSheet> Factory::InstanceStyleSheetFile(const String& file_name)
{
	auto file_stream = MakeUnique<StreamFile>();
	file_stream->Open(file_name);
	return InstanceStyleSheetStream(file_stream.get());
}

// Creates a style sheet from an Stream.
SharedPtr<StyleSheet> Factory::InstanceStyleSheetStream(Stream* stream)
{
	SharedPtr<StyleSheet> style_sheet = MakeShared<StyleSheet>();
	if (style_sheet->LoadStyleSheet(stream))
	{
		return style_sheet;
	}
	return nullptr;
}

// Clears the style sheet cache. This will force style sheets to be reloaded.
void Factory::ClearStyleSheetCache()
{
	StyleSheetFactory::ClearStyleSheetCache();
}

/// Clears the template cache. This will force templates to be reloaded.
void Factory::ClearTemplateCache()
{
	TemplateCache::Clear();
}

// Registers an instancer for all RmlEvents
void Factory::RegisterEventInstancer(EventInstancer* instancer)
{
	event_instancer = instancer;
}

// Instance an event object.
EventPtr Factory::InstanceEvent(Element* target, EventId id, const Dictionary& parameters, bool interruptible)
{
	EventPtr event = event_instancer->InstanceEvent(target, id, parameters, interruptible);
	if (event)
		event->instancer = event_instancer;
	return event;
}

// Register an instancer for all event listeners
void Factory::RegisterEventListenerInstancer(EventListenerInstancer* instancer)
{
	event_listener_instancer = instancer;
}

// Instance an event listener with the given string
EventListener* Factory::InstanceEventListener(const String& value, Element* element)
{
	// If we have an event listener instancer, use it
	if (event_listener_instancer)
		return event_listener_instancer->InstanceEventListener(value, element);

	return nullptr;
}

void Factory::RegisterDataViewInstancer(DataViewInstancer* instancer, const String& name, bool is_structural_view)
{
	bool inserted = false;
	if (is_structural_view)
	{
		inserted = structural_data_view_instancers.emplace(name, instancer).second;
		if (inserted)
			structural_data_view_attribute_names.push_back(String("data-") + name);
	}
	else
	{
		inserted = data_view_instancers.emplace(name, instancer).second;
	}
	
	if (!inserted)
		Log::Message(Log::LT_WARNING, "Could not register data view instancer '%s'. The given name is already registered.", name.c_str());
}

void Factory::RegisterDataControllerInstancer(DataControllerInstancer* instancer, const String& name)
{
	bool inserted = data_controller_instancers.emplace(name, instancer).second;
	if (!inserted)
		Log::Message(Log::LT_WARNING, "Could not register data controller instancer '%s'. The given name is already registered.", name.c_str());
}

DataViewPtr Factory::InstanceDataView(const String& type_name, Element* element, bool is_structural_view)
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

DataControllerPtr Factory::InstanceDataController(const String& type_name, Element* element)
{
	auto it = data_controller_instancers.find(type_name);
	if (it != data_controller_instancers.end())
		return it->second->InstanceController(element);
	return DataControllerPtr();
}

bool Factory::IsStructuralDataView(const String& type_name)
{
	return structural_data_view_instancers.find(type_name) != structural_data_view_instancers.end();
}

const StringList& Factory::GetStructuralDataViewAttributeNames()
{
	return structural_data_view_attribute_names;
}

} // namespace Rml
