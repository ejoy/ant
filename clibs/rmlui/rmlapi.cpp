extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include "luaplugin.h"

#include <RmlUi/Core/Element.h>
#include <RmlUi/Core/ElementDocument.h>

static int
lDocumentGetContext(lua_State *L) {
	Rml::ElementDocument *doc = (Rml::ElementDocument *)lua_touserdata(L, 1);
	lua_pushlightuserdata(L, (void *)doc->GetContext());
	return 1;
}

static int
lDocumentGetTitle(lua_State *L) {
	Rml::ElementDocument *doc = (Rml::ElementDocument *)lua_touserdata(L, 1);
	const Rml::String &title = doc->GetTitle();
	lua_pushlstring(L, title.c_str(), title.length());
	return 1;
}

static int
lDocumentGetSourceURL(lua_State *L) {
	Rml::ElementDocument *doc = (Rml::ElementDocument *)lua_touserdata(L, 1);
	printf("SOURCE URL\n");
	const Rml::String &url = doc->GetSourceURL();
	lua_pushlstring(L, url.c_str(), url.length());
	return 1;
}

static int
lElementGetInnerRML(lua_State *L) {
	Rml::Element *e = (Rml::Element *)lua_touserdata(L, 1);
	const Rml::String &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

int
lua_plugin_apis(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "DocumentGetContext", lDocumentGetContext },
		{ "DocumentGetTitle", lDocumentGetTitle },
		{ "DocumentGetSourceURL", lDocumentGetSourceURL },
		{ "ElementGetInnerRML", lElementGetInnerRML },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

