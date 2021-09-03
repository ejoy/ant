#include <lua.hpp>

#include "RmlUi/Context.h"
#include "RmlUi/Core.h"
#include "RmlUi/Element.h"
#include "RmlUi/Document.h"
#include "RmlUi/EventListener.h"
#include "RmlUi/PropertyDictionary.h"
#include "RmlUi/StyleSheetSpecification.h"
#include "RmlUi/EventSpecification.h"

#include "luaplugin.h"
#include "luabind.h"

#include "render.h"
#include "file.h"
#include "font.h"
#include "context.h"

#include "../bgfx/bgfx_interface.h"
#include "../bgfx/luabgfx.h"
#include <bgfx/c99/bgfx.h>
#include <assert.h>
#include <string.h>

struct RmlInterface {
    FontEngine      m_font;
    File            m_file;
    Renderer        m_renderer;
    RmlInterface(RmlContext* context)
        : m_font(context)
        , m_file()
        , m_renderer(context)
    {
        Rml::SetFontEngineInterface(&m_font);
        Rml::SetFileInterface(&m_file);
        Rml::SetRenderInterface(&m_renderer);
    }
};

struct RmlWrapper {
    RmlContext   context;
    RmlInterface interface;
    RmlWrapper(lua_State* L, int idx)
        : context(L, idx)
        , interface(&context)
	{}
};

static RmlWrapper* g_wrapper = nullptr;
static lua_plugin* g_plugin = nullptr;

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

struct EventListener final : public Rml::EventListener {
	EventListener(lua_State* L_, const std::string& type, int funcref, bool use_capture)
		: Rml::EventListener(type, use_capture)
		, L(L_)
		, ref(funcref)
	{}
	~EventListener() {
		get_lua_plugin()->unref(ref);
	}
	void OnDetach(Rml::Element* element) override { delete this; }
	void ProcessEvent(Rml::Event& event) override {
		luabind::invoke([&](lua_State* L) {
			lua_pushevent(L, event);
			get_lua_plugin()->callref(L, ref, 1, 0);
		});
	}
	lua_State* L;
	int ref;
};

static int
lContextLoadDocument(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	const char* path = luaL_checkstring(L, 2);
	Rml::Document* doc = ctx->LoadDocument(path);
	if (!doc) {
		return 0;
	}
	lua_pushlightuserdata(L, doc);
	return 1;
}

static int
lContextUnloadDocument(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 2);
	ctx->UnloadDocument(doc);
	return 0;
}

static int
lContextProcessMouseMove(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	Rml::MouseButton button = (Rml::MouseButton)luaL_checkinteger(L, 2);
	int x = (int)luaL_checkinteger(L, 3);
	int y = (int)luaL_checkinteger(L, 4);
	ctx->ProcessMouseMove(button, x, y, 0);
	return 0;
}

static int
lContextProcessMouseButtonDown(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	Rml::MouseButton button = (Rml::MouseButton)luaL_checkinteger(L, 2);
	int x = (int)luaL_checkinteger(L, 3);
	int y = (int)luaL_checkinteger(L, 4);
	ctx->ProcessMouseButtonDown(button, x, y, 0);
	return 0;
}

static int
lContextProcessMouseButtonUp(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	Rml::MouseButton button = (Rml::MouseButton)luaL_checkinteger(L, 2);
	int x = (int)luaL_checkinteger(L, 3);
	int y = (int)luaL_checkinteger(L, 4);
	ctx->ProcessMouseButtonUp(button, x, y, 0);
	return 0;
}

static int
lContextUpdate(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	double delta = luaL_checknumber(L, 2);
	ctx->Update(delta);
	return 0;
}

static int
lContextUpdateSize(lua_State *L){
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	ctx->SetDimensions(Rml::Size(
		(float)luaL_checkinteger(L, 2),
		(float)luaL_checkinteger(L, 3)));

	return 0;
}

static void
ElementAddEventListener(Rml::Element* e, const std::string& name, bool userCapture, lua_State* L, int idx) {
	luaL_checktype(L, 3, LUA_TFUNCTION);
	lua_pushvalue(L, 3);
	e->AddEventListener(new EventListener(L, name, get_lua_plugin()->ref(L), lua_toboolean(L, 4)));
}

static void
ElementDispatchEvent(Rml::Element* e, const std::string& name, lua_State* L, int idx) {
	Rml::EventId id = Rml::EventSpecification::GetId(name);
	if (id == Rml::EventId::Invalid) {
		return;
	}
	luabind::setthread(L);
	Rml::EventDictionary params;
	if (lua_type(L, idx) == LUA_TTABLE) {
		lua_pushnil(L);
		while (lua_next(L, idx)) {
			if (lua_type(L, -2) != LUA_TSTRING) {
				lua_pop(L, 1);
				continue;
			}
			Rml::EventDictionary::value_type v {lua_checkstdstring(L, -2), Rml::EventVariant{}};
			lua_getvariant(L, -1, &v.second);
			params.emplace(v);
			lua_pop(L, 1);
		}
	}
	e->DispatchEvent(id, params);
}

static int
lDocumentAddEventListener(lua_State* L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	ElementAddEventListener(doc->body.get(), lua_checkstdstring(L, 2), lua_toboolean(L, 4), L, 3);
	return 0;
}

static int
lDocumentClose(lua_State* L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	doc->Close();
	return 0;
}

static int
lDocumentGetContext(lua_State *L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	lua_pushlightuserdata(L, (void *)doc->GetContext());
	return 1;
}

static int
lDocumentGetElementById(lua_State* L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	lua_pushobject(L, doc->body->GetElementById(lua_checkstdstring(L, 2)));
	return 1;
}

static int
lDocumentGetSourceURL(lua_State *L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	const std::string &url = doc->GetSourceURL();
	lua_pushlstring(L, url.c_str(), url.length());
	return 1;
}

static int
lDocumentShow(lua_State* L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	doc->Show();
	return 0;
}

static int
lElementAddEventListener(lua_State* L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	ElementAddEventListener(e, lua_checkstdstring(L, 2), lua_toboolean(L, 4), L, 3);
	return 0;
}

static int
lDocumentDispatchEvent(lua_State* L) {
	luabind::setthread(L);
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	ElementDispatchEvent(doc->body.get(), lua_checkstdstring(L, 2), L, 3);
	return 0;
}

static int
lElementGetInnerRML(lua_State *L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const std::string &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

static int
lElementGetAttribute(lua_State* L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const std::string* attr = e->GetAttribute(lua_checkstdstring(L, 2));
	if (!attr) {
		return 0;
	}
	lua_pushlstring(L, attr->data(), attr->size());
	return 1;
}

static int
lElementGetBounds(lua_State* L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const Rml::Layout::Metrics& metrics = e->GetMetrics();
	lua_pushnumber(L, metrics.frame.origin.x);
	lua_pushnumber(L, metrics.frame.origin.y);
	lua_pushnumber(L, metrics.frame.size.w);
	lua_pushnumber(L, metrics.frame.size.h);
	return 4;
}

static int
lElementGetChildren(lua_State* L) {
	luabind::setthread(L);
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
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Document* doc = e->GetOwnerDocument();
	if (!doc) {
		return 0;
	}
	lua_pushlightuserdata(L, doc);
	return 1;
}

static int
lElementGetParent(lua_State* L) {
	luabind::setthread(L);
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
	luabind::setthread(L);
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
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveAttribute(lua_checkstdstring(L, 2));
	return 0;
}


static int
lElementRemoveProperty(lua_State* L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveProperty(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementSetAttribute(lua_State* L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetAttribute(lua_checkstdstring(L, 2), lua_checkstdstring(L, 3));
	return 0;
}

static int
lElementSetProperty(lua_State* L) {
	luabind::setthread(L);
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	std::string name = lua_checkstdstring(L, 2);
	std::string value = lua_checkstdstring(L, 3);
	bool ok = e->SetProperty(name, value);
	lua_pushboolean(L, ok);
	return 1;
}

static int
lRmlInitialise(lua_State* L) {
	luabind::setthread(L);
    if (g_wrapper) {
        return luaL_error(L, "RmlUi has been initialized.");
    }
    g_wrapper = new RmlWrapper(L, 1);
    if (!Rml::Initialise()){
        return luaL_error(L, "Failed to Initialise RmlUi.");
    }
	Rml::RegisterPlugin(g_plugin);
    return 0;
}

static int
lRmlShutdown(lua_State* L) {
	luabind::setthread(L);
    Rml::Shutdown();
    if (g_wrapper) {
        delete g_wrapper;
        g_wrapper = nullptr;
    }
    return 0;
}

static int
lRmlCreateContext(lua_State* L) {
	luabind::setthread(L);
	float w = (float)luaL_checkinteger(L, 1);
	float h = (float)luaL_checkinteger(L, 2);
	Rml::Context* ctx = new Rml::Context(Rml::Size(w, h));
	if (!ctx) {
		return 0;
	}
	lua_pushlightuserdata(L, ctx);
	return 1;
}

static int
lRmlRemoveContext(lua_State* L) {
	luabind::setthread(L);
	Rml::Context* ctx = lua_checkobject<Rml::Context>(L, 1);
	delete ctx;
	return 0;
}

static int
lRmlRegisterEevent(lua_State* L) {
	luabind::setthread(L);
	lua_plugin* plugin = get_lua_plugin();
	plugin->register_event(L);
	return 0;
}

static int
lRenderBegin(lua_State* L) {
    if (g_wrapper) {
        g_wrapper->interface.m_renderer.Begin();
    }
    return 0;
}

static int
lRenderFrame(lua_State* L){
    if (g_wrapper){
        g_wrapper->interface.m_renderer.Frame();
    }
    return 0;
}

static int
lUpdateViewrect(lua_State *L){
    if (g_wrapper){
        Rect &r = g_wrapper->context.viewrect;
        r.x = (int)luaL_checknumber(L, 1);
        r.y = (int)luaL_checknumber(L, 2);
        r.w = (int)luaL_checknumber(L, 3);
        r.h = (int)luaL_checknumber(L, 4);
        g_wrapper->interface.m_renderer.UpdateViewRect();
    }
    return 0;
}

}

int lDataModelCreate(lua_State* L);
int lDataModelRelease(lua_State* L);
int lDataModelDelete(lua_State* L);
int lDataModelGet(lua_State* L);
int lDataModelSet(lua_State* L);
int lDataModelDirty(lua_State* L);

lua_plugin* get_lua_plugin() {
    return g_plugin;
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_rmlui(lua_State* L) {
	luaL_checkversion(L);
    init_interface(L);
	g_plugin = new lua_plugin;
	luaL_Reg l[] = {
		{ "ContextLoadDocument", lContextLoadDocument },
		{ "ContextUnloadDocument", lContextUnloadDocument },
		{ "ContextProcessMouseMove", lContextProcessMouseMove },
		{ "ContextProcessMouseButtonDown", lContextProcessMouseButtonDown },
		{ "ContextProcessMouseButtonUp", lContextProcessMouseButtonUp },
		{ "ContextUpdate", lContextUpdate },
		{ "ContextUpdateSize", lContextUpdateSize},
		{ "DataModelCreate", lDataModelCreate },
		{ "DataModelRelease", lDataModelRelease },
		{ "DataModelRelease", lDataModelDelete },
		{ "DataModelGet", lDataModelGet },
		{ "DataModelSet", lDataModelSet },
		{ "DataModelDirty", lDataModelDirty },
		{ "DocumentClose", lDocumentClose },
		{ "DocumentAddEventListener", lDocumentAddEventListener },
		{ "DocumentDispatchEvent", lDocumentDispatchEvent },
		{ "DocumentGetContext", lDocumentGetContext },
		{ "DocumentGetElementById", lDocumentGetElementById },
		{ "DocumentGetSourceURL", lDocumentGetSourceURL },
		{ "DocumentShow", lDocumentShow },
		{ "ElementAddEventListener", lElementAddEventListener },
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
		{ "RenderBegin", lRenderBegin },
		{ "RenderFrame", lRenderFrame },
		{ "UpdateViewrect", lUpdateViewrect},
		{ "RmlInitialise", lRmlInitialise },
		{ "RmlShutdown", lRmlShutdown },
		{ "RmlCreateContext", lRmlCreateContext },
		{ "RmlRemoveContext", lRmlRemoveContext },
		{ "RmlRegisterEevent", lRmlRegisterEevent },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
