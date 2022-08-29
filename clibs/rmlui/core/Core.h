#pragma once

namespace Rml {

class Plugin;
class FileInterface;
class FontEngineInterface;
class RenderInterface;

bool Initialise();
void Shutdown();
void SetRenderInterface(RenderInterface* render_interface);
RenderInterface* GetRenderInterface();
void SetFontEngineInterface(FontEngineInterface* font_interface);
FontEngineInterface* GetFontEngineInterface();
void SetPlugin(Plugin* plugin);
Plugin* GetPlugin();

}
