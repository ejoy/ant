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

#include "../../Include/RmlUi/Core/Core.h"
#include "../../Include/RmlUi/Core/Context.h"
#include "../../Include/RmlUi/Core/Factory.h"
#include "../../Include/RmlUi/Core/FileInterface.h"
#include "../../Include/RmlUi/Core/FontEngineInterface.h"
#include "../../Include/RmlUi/Core/Plugin.h"
#include "../../Include/RmlUi/Core/RenderInterface.h"
#include "../../Include/RmlUi/Core/SystemInterface.h"
#include "../../Include/RmlUi/Core/StyleSheetSpecification.h"
#include "../../Include/RmlUi/Core/Types.h"

#include "EventSpecification.h"
#include "FileInterfaceDefault.h"
#include "GeometryDatabase.h"
#include "PluginRegistry.h"
#include "StyleSheetFactory.h"
#include "StyleSheetParser.h"
#include "TemplateCache.h"
#include "TextureDatabase.h"
#include "EventSpecification.h"

namespace Rml {

// RmlUi's renderer interface.
static RenderInterface* render_interface = nullptr;
/// RmlUi's system interface.
static SystemInterface* system_interface = nullptr;
// RmlUi's file I/O interface.
static FileInterface* file_interface = nullptr;
// RmlUi's font engine interface.
static FontEngineInterface* font_interface = nullptr;

// Default interfaces should be created and destroyed on Initialise and Shutdown, respectively.
static UniquePtr<FileInterface> default_file_interface;
static UniquePtr<FontEngineInterface> default_font_interface;

static bool initialised = false;

#ifndef RMLUI_VERSION
	#define RMLUI_VERSION "custom"
#endif

bool Initialise() {
	RMLUI_ASSERTMSG(!initialised, "Rml::Initialise() called, but RmlUi is already initialised!");
	Log::Initialise();
	if (!render_interface) {
		Log::Message(Log::LT_ERROR, "No render interface set!");
		return false;
	}
	if (!system_interface) {	
		Log::Message(Log::LT_ERROR, "No system interface set!");
		return false;
	}
	if (!file_interface) {
		Log::Message(Log::LT_ERROR, "No file interface set!");
		return false;
	}
	EventSpecificationInterface::Initialize();
	TextureDatabase::Initialise();
	if (!font_interface) {
		Log::Message(Log::LT_ERROR, "No font interface set!");
		return false;
	}
	StyleSheetSpecification::Initialise();
	StyleSheetParser::Initialise();
	StyleSheetFactory::Initialise();
	TemplateCache::Initialise();
	Factory::Initialise();
	PluginRegistry::NotifyInitialise();
	initialised = true;
	return true;
}

void Shutdown() {
	RMLUI_ASSERTMSG(initialised, "Rml::Shutdown() called, but RmlUi is not initialised!");

	// Notify all plugins we're being shutdown.
	PluginRegistry::NotifyShutdown();

	Factory::Shutdown();
	TemplateCache::Shutdown();
	StyleSheetFactory::Shutdown();
	StyleSheetParser::Shutdown();
	StyleSheetSpecification::Shutdown();

	font_interface = nullptr;
	default_font_interface.reset();

	TextureDatabase::Shutdown();

	initialised = false;

	render_interface = nullptr;
	file_interface = nullptr;
	system_interface = nullptr;

	default_file_interface.reset();

	Log::Shutdown();
}

// Returns the version of this RmlUi library.
String GetVersion()
{
	return RMLUI_VERSION;
}

// Sets the interface through which all RmlUi messages will be routed.
void SetSystemInterface(SystemInterface* _system_interface)
{
	system_interface = _system_interface;
}

// Returns RmlUi's system interface.
SystemInterface* GetSystemInterface()
{
	return system_interface;
}

// Sets the interface through which all rendering requests are made.
void SetRenderInterface(RenderInterface* _render_interface)
{
	render_interface = _render_interface;
}

// Returns RmlUi's render interface.
RenderInterface* GetRenderInterface()
{
	return render_interface;
}

// Sets the interface through which all file I/O requests are made.
void SetFileInterface(FileInterface* _file_interface)
{
	file_interface = _file_interface;
}

// Returns RmlUi's file interface.
FileInterface* GetFileInterface()
{
	return file_interface;
}

// Sets the interface through which all font requests are made.
void SetFontEngineInterface(FontEngineInterface* _font_interface)
{
	font_interface = _font_interface;
}
	
// Returns RmlUi's file interface.
FontEngineInterface* GetFontEngineInterface()
{
	return font_interface;
}

bool LoadFontFace(const String& file_name, bool fallback_face)
{
	return font_interface->LoadFontFace(file_name, fallback_face);
}

bool LoadFontFace(const byte* data, int data_size, const String& font_family, Style::FontStyle style, Style::FontWeight weight, bool fallback_face)
{
	return font_interface->LoadFontFace(data, data_size, font_family, style, weight, fallback_face);
}

// Registers a generic rmlui plugin
void RegisterPlugin(Plugin* plugin)
{
	if (initialised)
		plugin->OnInitialise();

	PluginRegistry::RegisterPlugin(plugin);
}

EventId RegisterEventType(const String& type, bool interruptible, bool bubbles, DefaultActionPhase default_action_phase)
{
	return EventSpecificationInterface::InsertOrReplaceCustom(type, interruptible, bubbles, default_action_phase);
}

StringList GetTextureSourceList()
{
	return TextureDatabase::GetSourceList();
}

void ReleaseTextures()
{
	TextureDatabase::ReleaseTextures();
}

void ReleaseCompiledGeometry()
{
	return GeometryDatabase::ReleaseAll();
}

} // namespace Rml
