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

#include "../Include/RmlUi/Core.h"
#include "../Include/RmlUi/Context.h"
#include "../Include/RmlUi/Factory.h"
#include "../Include/RmlUi/FileInterface.h"
#include "../Include/RmlUi/FontEngineInterface.h"
#include "../Include/RmlUi/Plugin.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Texture.h"
#include "../Include/RmlUi/Log.h"
#include "EventSpecification.h"
#include "FileInterfaceDefault.h"
#include "PluginRegistry.h"
#include "StyleSheetFactory.h"
#include "StyleSheetParser.h"
#include "EventSpecification.h"

namespace Rml {

// RmlUi's renderer interface.
static RenderInterface* render_interface = nullptr;
// RmlUi's file I/O interface.
static FileInterface* file_interface = nullptr;
// RmlUi's font engine interface.
static FontEngineInterface* font_interface = nullptr;

// Default interfaces should be created and destroyed on Initialise and Shutdown, respectively.
static std::unique_ptr<FileInterface> default_file_interface;
static std::unique_ptr<FontEngineInterface> default_font_interface;

static bool initialised = false;

#ifndef RMLUI_VERSION
	#define RMLUI_VERSION "custom"
#endif

bool Initialise() {
	RMLUI_ASSERTMSG(!initialised, "Rml::Initialise() called, but RmlUi is already initialised!");
	if (!render_interface) {
		Log::Message(Log::Level::Error, "No render interface set!");
		return false;
	}
	if (!file_interface) {
		Log::Message(Log::Level::Error, "No file interface set!");
		return false;
	}
	EventSpecificationInterface::Initialize();
	if (!font_interface) {
		Log::Message(Log::Level::Error, "No font interface set!");
		return false;
	}
	StyleSheetSpecification::Initialise();
	StyleSheetParser::Initialise();
	StyleSheetFactory::Initialise();
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
	StyleSheetFactory::Shutdown();
	StyleSheetParser::Shutdown();
	StyleSheetSpecification::Shutdown();

	font_interface = nullptr;
	default_font_interface.reset();

	Texture::Shutdown();

	initialised = false;

	render_interface = nullptr;
	file_interface = nullptr;

	default_file_interface.reset();
}

// Returns the version of this RmlUi library.
std::string GetVersion()
{
	return RMLUI_VERSION;
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

// Registers a generic rmlui plugin
void RegisterPlugin(Plugin* plugin)
{
	if (initialised)
		plugin->OnInitialise();

	PluginRegistry::RegisterPlugin(plugin);
}

} // namespace Rml
