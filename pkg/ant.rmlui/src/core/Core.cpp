#include <core/Core.h>
#include <core/Interface.h>
#include <core/StyleSheetSpecification.h>
#include <core/Texture.h>
#include <core/Log.h>
#include <core/StyleSheetFactory.h>
#include <core/StyleSheetParser.h>

namespace Rml {

static RenderInterface* render_interface = nullptr;
static Plugin* plugin = nullptr;

static bool initialised = false;

bool Initialise() {
	assert(!initialised);
	if (!render_interface) {
		Log::Message(Log::Level::Error, "No render interface set!");
		return false;
	}
	if (!plugin) {
		Log::Message(Log::Level::Error, "No plugin set!");
		return false;
	}
	StyleSheetSpecification::Initialise();
	StyleSheetFactory::Initialise();
	initialised = true;
	return true;
}

void Shutdown() {
	assert(initialised);

	StyleSheetFactory::Shutdown();
	StyleSheetSpecification::Shutdown();
	Texture::Shutdown();

	render_interface = nullptr;
	initialised = false;
}

void SetRenderInterface(RenderInterface* _render_interface) {
	render_interface = _render_interface;
}

RenderInterface* GetRenderInterface() {
	return render_interface;
}

void SetPlugin(Plugin* _plugin) {
	plugin = _plugin;
}

Plugin* GetPlugin() {
	return plugin;
}

}
