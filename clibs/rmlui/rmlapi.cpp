#include "pch.h"

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include "luaplugin.h"
#include "luabind.h"

#include <RmlUi/Core/Element.h>
#include <RmlUi/Core/ElementDocument.h>

static void
lua_pushobject(lua_State* L, void* handle) {
	if (handle) {
		lua_pushlightuserdata(L, handle);
	}
	else {
		lua_pushnil(L);
	}
}

template <typename T>
T* lua_checkobject(lua_State* L, int idx) {
	luaL_checktype(L, idx, LUA_TLIGHTUSERDATA);
	return static_cast<T*>(lua_touserdata(L, 1));
}

static std::string
lua_checkstdstring(lua_State* L, int idx) {
	size_t sz = 0;
	const char* str = luaL_checklstring(L, idx, &sz);
	return std::string(str, sz);
}

static void
lua_pushstdstring(lua_State* L, const std::string& str) {
	lua_pushlstring(L, str.data(), str.size());
}

namespace {
	
static int
lContextLoadDocument(lua_State* L) {
	Rml::Context* ctx = (Rml::Context*)lua_touserdata(L, 1);
	const char* path = luaL_checkstring(L, 2);
	Rml::ElementDocument* doc = ctx->LoadDocument(path);
	if (!doc) {
		return 0;
	}
	lua_pushlightuserdata(L, doc);
	return 1;
}

static int
lContextProcessMouseMove(lua_State* L) {
	Rml::Context* ctx = (Rml::Context*)lua_touserdata(L, 1);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	ctx->ProcessMouseMove(x, y, 0);
	return 0;
}

static int
lContextProcessMouseButtonDown(lua_State* L) {
	Rml::Context* ctx = (Rml::Context*)lua_touserdata(L, 1);
	int button = luaL_checkinteger(L, 2);
	ctx->ProcessMouseButtonDown(button, 0);
	return 0;
}

static int
lContextProcessMouseButtonUp(lua_State* L) {
	Rml::Context* ctx = (Rml::Context*)lua_touserdata(L, 1);
	int button = luaL_checkinteger(L, 2);
	ctx->ProcessMouseButtonUp(button, 0);
	return 0;
}

static int
lContextRender(lua_State* L) {
	Rml::Context* ctx = (Rml::Context*)lua_touserdata(L, 1);
	ctx->Render();
	return 0;
}

static int
lContextUpdate(lua_State* L) {
	Rml::Context* ctx = (Rml::Context*)lua_touserdata(L, 1);
	ctx->Update();
	return 0;
}

static int
lDocumentClose(lua_State* L) {
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 1);
	doc->Close();
	return 0;
}

static int
lDocumentGetContext(lua_State *L) {
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 1);
	lua_pushlightuserdata(L, (void *)doc->GetContext());
	return 1;
}

static int
lDocumentGetElementById(lua_State* L) {
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 1);
	lua_pushobject(L, doc->GetElementById(lua_checkstdstring(L, 2)));
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
	const Rml::String &url = doc->GetSourceURL();
	lua_pushlstring(L, url.c_str(), url.length());
	return 1;
}

static int
lDocumentShow(lua_State* L) {
	Rml::ElementDocument* doc = (Rml::ElementDocument*)lua_touserdata(L, 1);
	doc->Show();
	return 1;
}

struct EventListener final : public Rml::EventListener {
	EventListener(lua_State* L_, int idx)
		: L(L_)
		, ref(LUA_NOREF)
	{
		luaL_checktype(L, idx, LUA_TFUNCTION);
		lua_pushvalue(L, idx);
		ref = get_lua_plugin()->ref(L);
	}
	~EventListener() {
		get_lua_plugin()->unref(ref);
	}
	void OnDetach(Rml::Element* element) override { delete this; }
	void ProcessEvent(Rml::Event& event) override {
		luabind::invoke(L, [&]() {
			lua_pushevent(L, event);
			get_lua_plugin()->callref(ref, 1, 0);
		});
	}
	lua_State* L;
	int ref;
};

static int
lElementAddEventListener(lua_State* L) {
	Rml::Element* e = (Rml::Element*)lua_touserdata(L, 1);
	e->AddEventListener(lua_checkstdstring(L, 2), new EventListener(L, 3), lua_toboolean(L, 4));
	return 0;
}

static int
lElementGetInnerRML(lua_State *L) {
	Rml::Element *e = (Rml::Element *)lua_touserdata(L, 1);
	const Rml::String &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

static int
lElementGetProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const Rml::Property* prop = e->GetProperty(lua_checkstdstring(L, 2));
	if (!prop) {
		return 0;
	}
	lua_pushstdstring(L, prop->ToString());
	return 1;
}

static int
lElementRemoveProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveProperty(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementSetProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	bool ok = e->SetProperty(lua_checkstdstring(L, 2), lua_checkstdstring(L, 3));
	lua_pushboolean(L, ok);
	return 1;
}

static int
lRmlCreateContext(lua_State* L) {
	const char* name = luaL_checkstring(L, 1);
	int w = luaL_checkinteger(L, 2);
	int h = luaL_checkinteger(L, 3);
	Rml::Context* ctx = Rml::CreateContext(name, Rml::Vector2i(w, h));
	if (!ctx) {
		return 0;
	}
	lua_pushlightuserdata(L, ctx);
	return 1;
}

static int
lLog(lua_State* L) {
	Rml::Log::Type type = (Rml::Log::Type)luaL_checkinteger(L, 1);
	size_t sz = 0;
	const char* msg = luaL_checklstring(L, 2, &sz);
	Rml::GetSystemInterface()->LogMessage(type, Rml::String(msg, sz));
	return 0;
}

}

int lDataModelCreate(lua_State* L);
int lDataModelRelease(lua_State* L);
int lDataModelDelete(lua_State* L);
int lDataModelGet(lua_State* L);
int lDataModelSet(lua_State* L);
int lDataModelDirty(lua_State* L);
int lRenderBegin(lua_State* L);
int lRenderFrame(lua_State* L);

int
lua_plugin_apis(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "ContextLoadDocument", lContextLoadDocument },
		{ "ContextProcessMouseMove", lContextProcessMouseMove },
		{ "ContextProcessMouseButtonDown", lContextProcessMouseButtonDown },
		{ "ContextProcessMouseButtonUp", lContextProcessMouseButtonUp },
		{ "ContextRender", lContextRender },
		{ "ContextUpdate", lContextUpdate },
		{ "DataModelCreate", lDataModelCreate },
		{ "DataModelRelease", lDataModelRelease },
		{ "DataModelRelease", lDataModelDelete },
		{ "DataModelGet", lDataModelGet },
		{ "DataModelSet", lDataModelSet },
		{ "DataModelDirty", lDataModelDirty },
		{ "DocumentClose", lDocumentClose },
		{ "DocumentGetContext", lDocumentGetContext },
		{ "DocumentGetElementById", lDocumentGetElementById },
		{ "DocumentGetTitle", lDocumentGetTitle },
		{ "DocumentGetSourceURL", lDocumentGetSourceURL },
		{ "DocumentShow", lDocumentShow },
		{ "ElementAddEventListener", lElementAddEventListener },
		{ "ElementGetInnerRML", lElementGetInnerRML },
		{ "ElementGetProperty", lElementGetProperty },
		{ "ElementRemoveProperty", lElementRemoveProperty },
		{ "ElementSetProperty", lElementSetProperty },
		{ "Log", lLog },
		{ "RenderBegin", lRenderBegin },
		{ "RenderFrame", lRenderFrame },
		{ "RmlCreateContext", lRmlCreateContext },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}
