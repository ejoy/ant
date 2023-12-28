#include <core/Core.h>
#include <core/Interface.h>
#include <css/StyleSheetSpecification.h>
#include <core/Texture.h>
#include <util/Log.h>
#include <css/StyleSheetFactory.h>
#include <css/StyleSheetParser.h>

namespace Rml {

static Render* g_render = nullptr;
static Script* g_script = nullptr;

static bool initialised = false;

bool Initialise() {
	assert(!initialised);
	if (!g_render) {
		Log::Message(Log::Level::Error, "No render set!");
		return false;
	}
	if (!g_script) {
		Log::Message(Log::Level::Error, "No script set!");
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

	g_render = nullptr;
	initialised = false;
}

void SetRender(Render* render) {
	g_render = render;
}

Render* GetRender() {
	return g_render;
}

void SetScript(Script* script) {
	g_script = script;
}

Script* GetScript() {
	return g_script;
}

}
