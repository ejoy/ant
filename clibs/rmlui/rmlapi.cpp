#include <lua.hpp>

#include "RmlUi/Context.h"
#include "RmlUi/Core.h"
#include "RmlUi/Element.h"
#include "RmlUi/ElementDocument.h"
#include "RmlUi/EventListener.h"
#include "RmlUi/PropertyDictionary.h"
#include "RmlUi/StyleSheetSpecification.h"
#include "RmlUi/SystemInterface.h"

#include "luaplugin.h"
#include "luabind.h"

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
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	const char* path = luaL_checkstring(L, 2);
	Rml::ElementDocument* doc = ctx->LoadDocument(path);
	if (!doc) {
		return 0;
	}
	lua_pushlightuserdata(L, doc);
	return 1;
}

static int
lContextUnloadDocument(lua_State* L) {
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 2);
	ctx->UnloadDocument(doc);
	return 0;
}

static int
lContextProcessMouseMove(lua_State* L) {
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	int x = luaL_checkinteger(L, 2);
	int y = luaL_checkinteger(L, 3);
	ctx->ProcessMouseMove(x, y, 0);
	return 0;
}

static int
lContextProcessMouseButtonDown(lua_State* L) {
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	int button = luaL_checkinteger(L, 2);
	ctx->ProcessMouseButtonDown(button, 0);
	return 0;
}

static int
lContextProcessMouseButtonUp(lua_State* L) {
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	int button = luaL_checkinteger(L, 2);
	ctx->ProcessMouseButtonUp(button, 0);
	return 0;
}

static int
lContextUpdate(lua_State* L) {
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
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
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 1);
	const Rml::String &title = doc->GetTitle();
	lua_pushlstring(L, title.c_str(), title.length());
	return 1;
}

static int
lDocumentGetSourceURL(lua_State *L) {
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 1);
	const Rml::String &url = doc->GetSourceURL();
	lua_pushlstring(L, url.c_str(), url.length());
	return 1;
}

static int
lDocumentShow(lua_State* L) {
	Rml::ElementDocument* doc = lua_checkobject<Rml::ElementDocument>(L, 1);
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
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->AddEventListener(lua_checkstdstring(L, 2), new EventListener(L, 3), lua_toboolean(L, 4));
	return 0;
}
static int
lElementDispatchEvent(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Dictionary params;
	if (lua_type(L, 3) == LUA_TTABLE) {
		lua_pushnil(L);
		while (lua_next(L, 3)) {
			if (lua_type(L, -2) != LUA_TSTRING) {
				lua_pop(L, 1);
				continue;
			}
			Rml::Dictionary::value_type v;
			v.first = lua_checkstdstring(L, -2);
			lua_getvariant(L, -1, &v.second);
			params.emplace(v);
			lua_pop(L, 1);
		}
	}
	e->DispatchEvent(lua_checkstdstring(L, 2), params);
	return 0;
}

static int
lElementGetInnerRML(lua_State *L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const Rml::String &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

static int
lElementGetAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const Rml::Variant* attr = e->GetAttribute(lua_checkstdstring(L, 2));
	if (!attr) {
		return 0;
	}
	lua_pushvariant(L, *attr);
	return 1;
}

static int
lElementGetBounds(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const Rml::Vector4f& bounds = e->GetBounds();
	lua_pushnumber(L, bounds[0]);
	lua_pushnumber(L, bounds[1]);
	lua_pushnumber(L, bounds[2]);
	lua_pushnumber(L, bounds[3]);
	return 4;
}

static int
lElementGetChildren(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	if (lua_type(L, 2) != LUA_TNUMBER) {
		lua_pushinteger(L, e->GetNumChildren());
		return 1;
	}
	Rml::Element* child = e->GetChild((int)lua_tointeger(L, 2));
	if (child) {
		lua_pushlightuserdata(L, child);
		return 1;
	}
	return 0;
}

static int
lElementGetOwnerDocument(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::ElementDocument* doc = e->GetOwnerDocument();
	if (!doc) {
		return 0;
	}
	lua_pushlightuserdata(L, doc);
	return 1;
}

static int
lElementGetParent(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Element* parent = e->GetParentNode();
	if (!parent) {
		return 0;
	}
	lua_pushlightuserdata(L, parent);
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
lElementRemoveAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveAttribute(lua_checkstdstring(L, 2));
	return 0;
}


static int
lElementRemoveProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveProperty(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementSetAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Variant attr;
	lua_getvariant(L, 3, &attr);
	e->SetAttribute(lua_checkstdstring(L, 2), attr);
	return 0;
}

static int
lElementSetProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::String name = lua_checkstdstring(L, 2);
	Rml::String value = lua_checkstdstring(L, 3);
	Rml::PropertyDictionary properties;
	if (Rml::StyleSheetSpecification::ParsePropertyDeclaration(properties, name, value)) {
		auto source = std::make_shared<Rml::PropertySource>(
			"TODO",
			0,
			"Lua"
		);
		properties.SetSourceOfAllProperties(source);
		for (auto& property : properties.GetProperties()) {
			if (!e->SetProperty(property.first, property.second)) {
				lua_pushboolean(L, 0);
				return 1;
			}
		}
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int
lRmlCreateContext(lua_State* L) {
	int w = luaL_checkinteger(L, 1);
	int h = luaL_checkinteger(L, 2);
	Rml::Context* ctx = new Rml::Context(Rml::Vector2i(w, h));
	if (!ctx) {
		return 0;
	}
	lua_pushlightuserdata(L, ctx);
	return 1;
}

static int
lRmlRemoveContext(lua_State* L) {
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	delete ctx;
	return 0;
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
		{ "ContextUnloadDocument", lContextUnloadDocument },
		{ "ContextProcessMouseMove", lContextProcessMouseMove },
		{ "ContextProcessMouseButtonDown", lContextProcessMouseButtonDown },
		{ "ContextProcessMouseButtonUp", lContextProcessMouseButtonUp },
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
		{ "ElementDispatchEvent", lElementDispatchEvent },
		{ "ElementGetInnerRML", lElementGetInnerRML },
		{ "ElementGetAttribute", lElementGetAttribute },
		{ "ElementGetBounds", lElementGetBounds },
		{ "ElementGetChildren", lElementGetChildren },
		{ "ElementGetOwnerDocument", lElementGetOwnerDocument },
		{ "ElementGetParent", lElementGetParent },
		{ "ElementGetProperty", lElementGetProperty },
		{ "ElementRemoveAttribute", lElementRemoveAttribute },
		{ "ElementRemoveProperty", lElementRemoveProperty },
		{ "ElementSetAttribute", lElementSetAttribute },
		{ "ElementSetProperty", lElementSetProperty },
		{ "Log", lLog },
		{ "RenderBegin", lRenderBegin },
		{ "RenderFrame", lRenderFrame },
		{ "RmlCreateContext", lRmlCreateContext },
		{ "RmlRemoveContext", lRmlRemoveContext },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}
