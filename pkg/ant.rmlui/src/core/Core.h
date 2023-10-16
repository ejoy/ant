#pragma once

namespace Rml {

class Plugin;
class RenderInterface;

bool Initialise();
void Shutdown();
void SetRenderInterface(RenderInterface* render_interface);
RenderInterface* GetRenderInterface();
void SetPlugin(Plugin* plugin);
Plugin* GetPlugin();

}
