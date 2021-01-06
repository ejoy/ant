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

#ifndef RMLUI_CORE_CORE_H
#define RMLUI_CORE_CORE_H

#include "Header.h"
#include "Types.h"
#include "Event.h"
#include "ComputedValues.h"

namespace Rml {

class Plugin;
class Context;
class FileInterface;
class FontEngineInterface;
class RenderInterface;
class SystemInterface;
enum class DefaultActionPhase;


RMLUICORE_API bool Initialise();
RMLUICORE_API void Shutdown();
RMLUICORE_API String GetVersion();
RMLUICORE_API void SetSystemInterface(SystemInterface* system_interface);
RMLUICORE_API SystemInterface* GetSystemInterface();
RMLUICORE_API void SetRenderInterface(RenderInterface* render_interface);
RMLUICORE_API RenderInterface* GetRenderInterface();
RMLUICORE_API void SetFileInterface(FileInterface* file_interface);
RMLUICORE_API FileInterface* GetFileInterface();
RMLUICORE_API void SetFontEngineInterface(FontEngineInterface* font_interface);
RMLUICORE_API FontEngineInterface* GetFontEngineInterface();
RMLUICORE_API bool LoadFontFace(const String& file_name, bool fallback_face = false);
RMLUICORE_API bool LoadFontFace(const byte* data, int data_size, const String& font_family, Style::FontStyle style, Style::FontWeight weight, bool fallback_face = false);
RMLUICORE_API void RegisterPlugin(Plugin* plugin);
RMLUICORE_API EventId RegisterEventType(const String& type, bool interruptible, bool bubbles, DefaultActionPhase default_action_phase = DefaultActionPhase::None);
RMLUICORE_API void ReleaseTextures();
RMLUICORE_API void ReleaseCompiledGeometry();

}

#endif
