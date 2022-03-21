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
#include "../Include/RmlUi/DataUtilities.h"
#include "../Include/RmlUi/FileInterface.h"
#include "../Include/RmlUi/FontEngineInterface.h"
#include "../Include/RmlUi/Plugin.h"
#include "../Include/RmlUi/RenderInterface.h"
#include "../Include/RmlUi/StyleSheetSpecification.h"
#include "../Include/RmlUi/Types.h"
#include "../Include/RmlUi/Texture.h"
#include "../Include/RmlUi/Log.h"
#include "StyleSheetFactory.h"
#include "StyleSheetParser.h"

namespace Rml {

static RenderInterface* render_interface = nullptr;
static FileInterface* file_interface = nullptr;
static FontEngineInterface* font_interface = nullptr;
static Plugin* plugin = nullptr;

static bool initialised = false;

bool Initialise() {
	assert(!initialised);
	if (!render_interface) {
		Log::Message(Log::Level::Error, "No render interface set!");
		return false;
	}
	if (!file_interface) {
		Log::Message(Log::Level::Error, "No file interface set!");
		return false;
	}
	if (!font_interface) {
		Log::Message(Log::Level::Error, "No font interface set!");
		return false;
	}
	if (!plugin) {
		Log::Message(Log::Level::Error, "No plugin set!");
		return false;
	}
	StyleSheetSpecification::Initialise();
	StyleSheetFactory::Initialise();
	DataUtilities::Initialise();
	initialised = true;
	return true;
}

void Shutdown() {
	assert(initialised);

	DataUtilities::Shutdown();
	StyleSheetFactory::Shutdown();
	StyleSheetSpecification::Shutdown();
	Texture::Shutdown();

	font_interface = nullptr;
	render_interface = nullptr;
	file_interface = nullptr;
	initialised = false;
}

void SetRenderInterface(RenderInterface* _render_interface) {
	render_interface = _render_interface;
}

RenderInterface* GetRenderInterface() {
	return render_interface;
}

void SetFileInterface(FileInterface* _file_interface) {
	file_interface = _file_interface;
}

FileInterface* GetFileInterface() {
	return file_interface;
}

void SetFontEngineInterface(FontEngineInterface* _font_interface) {
	font_interface = _font_interface;
}

FontEngineInterface* GetFontEngineInterface() {
	return font_interface;
}

void SetPlugin(Plugin* _plugin) {
	plugin = _plugin;
}

Plugin* GetPlugin() {
	return plugin;
}

}
