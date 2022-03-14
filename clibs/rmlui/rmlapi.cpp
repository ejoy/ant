#include <lua.hpp>

#include "RmlUi/Core.h"
#include "RmlUi/Element.h"
#include "RmlUi/Document.h"
#include "RmlUi/EventListener.h"
#include "RmlUi/PropertyDictionary.h"
#include "RmlUi/StyleSheetSpecification.h"
#include "RmlUi/Time.h"

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
	lua_plugin      m_plugin;
    RmlInterface(RmlContext* context)
        : m_font(context)
        , m_file()
        , m_renderer(context)
    {
        Rml::SetFontEngineInterface(&m_font);
        Rml::SetFileInterface(&m_file);
        Rml::SetRenderInterface(&m_renderer);
		Rml::SetPlugin(&m_plugin);
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
	return static_cast<T*>(lua_touserdata(L, idx));
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
			get_lua_plugin()->pushevent(L, event);
			get_lua_plugin()->callref(L, ref, 1, 0);
		});
	}
	lua_State* L;
	int ref;
};

static int
lDocumentCreate(lua_State* L) {
	Rml::Size dimensions(
		(float)luaL_checkinteger(L, 1),
		(float)luaL_checkinteger(L, 2)
	);
	Rml::Document* doc = new Rml::Document(dimensions);
	lua_pushlightuserdata(L, doc);
	return 1;
}

static int
lDocumentLoad(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	std::string url = lua_checkstdstring(L, 2);
	bool ok = doc->Load(url);
	lua_pushboolean(L, ok);
	return 1;
}

static int
lDocumentDestroy(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	delete doc;
	return 0;
}

static int
lDocumentUpdate(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	doc->Update();
	return 0;
}

static int
lDocumentSetDimensions(lua_State *L){
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	doc->SetDimensions(Rml::Size(
		(float)luaL_checkinteger(L, 2),
		(float)luaL_checkinteger(L, 3))
	);
	return 0;
}

static int
lDocumentElementFromPoint(lua_State *L){
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	Rml::Element* e = doc->ElementFromPoint(Rml::Point(
		(float)luaL_checknumber(L, 2),
		(float)luaL_checknumber(L, 3))
	);
	if (!e) {
		return 0;
	}
	lua_pushlightuserdata(L, e);
	return 1;
}

static int
lDocumentGetBody(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	Rml::Element* e = doc->GetBody();
	lua_pushlightuserdata(L, e);
	return 1;
}

static void
ElementAddEventListener(Rml::Element* e, const std::string& name, bool userCapture, lua_State* L, int idx) {
	luaL_checktype(L, 3, LUA_TFUNCTION);
	lua_pushvalue(L, 3);
	e->AddEventListener(new EventListener(L, name, get_lua_plugin()->ref(L), lua_toboolean(L, 4)));
}

static bool
ElementDispatchEvent(Rml::Element* e, const std::string& type, bool interruptible, bool bubbles, lua_State* L, int parameters) {
	luaL_checktype(L, parameters, LUA_TTABLE);
	lua_pushvalue(L, parameters);
	return e->DispatchEvent(type, get_lua_plugin()->ref(L), interruptible, bubbles);
}

static int
lDocumentAddEventListener(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	ElementAddEventListener(doc->GetBody(), lua_checkstdstring(L, 2), lua_toboolean(L, 4), L, 3);
	return 0;
}

static int
lDocumentGetElementById(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	lua_pushobject(L, doc->GetBody()->GetElementById(lua_checkstdstring(L, 2)));
	return 1;
}

static int
lDocumentGetSourceURL(lua_State *L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	const std::string &url = doc->GetSourceURL();
	lua_pushlstring(L, url.c_str(), url.length());
	return 1;
}

static int
lElementAddEventListener(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	ElementAddEventListener(e, lua_checkstdstring(L, 2), lua_toboolean(L, 4), L, 3);
	return 0;
}

static int
lDocumentDispatchEvent(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	bool propagating = ElementDispatchEvent(doc->GetBody(), lua_checkstdstring(L, 2), false, false, L, 3);
	lua_pushboolean(L, propagating);
	return 1;
}

static int
lElementDispatchEvent(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	bool propagating = ElementDispatchEvent(e, lua_checkstdstring(L, 2), true, true, L, 3);
	lua_pushboolean(L, propagating);
	return 1;
}

static int
lElementSetPseudoClass(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const char* lst[] = { "hover", "active", NULL };
	Rml::PseudoClass pseudoClass = (Rml::PseudoClass)(1 + luaL_checkoption(L, 2, NULL, lst));
	e->SetPseudoClass(pseudoClass, lua_toboolean(L, 3));
	return 0;
}

static int
lElementGetInnerRML(lua_State *L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const std::string &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

static int
lElementGetAttribute(lua_State* L) {
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
	Rml::Document* doc = e->GetOwnerDocument();
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
	std::optional<std::string> prop = e->GetProperty(lua_checkstdstring(L, 2));
	if (!prop) {
		return 0;
	}
	lua_pushstdstring(L, prop.value());
	return 1;
}

static int
lElementRemoveAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveAttribute(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementSetAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetAttribute(lua_checkstdstring(L, 2), lua_checkstdstring(L, 3));
	return 0;
}

static int
lElementSetProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	std::string name = lua_checkstdstring(L, 2);
	if (lua_isnoneornil(L, 3)) {
		e->SetProperty(name);
	}
	else {
		std::string value = lua_checkstdstring(L, 3);
		e->SetProperty(name, value);
	}
	return 0;
}

static int
lElementSetPropertyImmediate(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	std::string name = lua_checkstdstring(L, 2);
	std::string value = lua_checkstdstring(L, 3);
	bool ok = e->SetPropertyImmediate(name, value);
	lua_pushboolean(L, ok);
	return 1;
}

static int
lElementProject(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Point pt(
		(float)luaL_checknumber(L, 2),
		(float)luaL_checknumber(L, 3)
	);
	if (!e->Project(pt)) {
		return 0;
	}
	lua_pushnumber(L, pt.x);
	lua_pushnumber(L, pt.y);
	return 2;
}

static int
lRmlInitialise(lua_State* L) {
    if (g_wrapper) {
        return luaL_error(L, "RmlUi has been initialized.");
    }
    g_wrapper = new RmlWrapper(L, 1);
    if (!Rml::Initialise()){
        return luaL_error(L, "Failed to Initialise RmlUi.");
    }
    return 0;
}

static int
lRmlShutdown(lua_State* L) {
    Rml::Shutdown();
    if (g_wrapper) {
        delete g_wrapper;
        g_wrapper = nullptr;
    }
    return 0;
}

static int
lRmlRegisterEevent(lua_State* L) {
	lua_plugin* plugin = get_lua_plugin();
	plugin->register_event(L);
	return 0;
}

static int
lRmlTimeUpdate(lua_State* L) {
	double delta = luaL_checknumber(L, 1);
	Rml::Time::Update(delta);
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

}

int lDataModelCreate(lua_State* L);
int lDataModelRelease(lua_State* L);
int lDataModelDelete(lua_State* L);
int lDataModelGet(lua_State* L);
int lDataModelSet(lua_State* L);
int lDataModelDirty(lua_State* L);

lua_plugin* get_lua_plugin() {
    return &g_wrapper->interface.m_plugin;
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_rmlui(lua_State* L) {
	luaL_checkversion(L);
	luabind::init(L);
	luaL_Reg l[] = {
		{ "DataModelCreate", lDataModelCreate },
		{ "DataModelRelease", lDataModelRelease },
		{ "DataModelRelease", lDataModelDelete },
		{ "DataModelGet", lDataModelGet },
		{ "DataModelSet", lDataModelSet },
		{ "DataModelDirty", lDataModelDirty },
		{ "DocumentCreate", lDocumentCreate },
		{ "DocumentLoad", lDocumentLoad },
		{ "DocumentDestroy", lDocumentDestroy },
		{ "DocumentUpdate", lDocumentUpdate },
		{ "DocumentSetDimensions", lDocumentSetDimensions},
		{ "DocumentElementFromPoint", lDocumentElementFromPoint },
		{ "DocumentAddEventListener", lDocumentAddEventListener },
		{ "DocumentDispatchEvent", lDocumentDispatchEvent },
		{ "DocumentGetElementById", lDocumentGetElementById },
		{ "DocumentGetSourceURL", lDocumentGetSourceURL },
		{ "DocumentGetBody", lDocumentGetBody },
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
		{ "ElementSetAttribute", lElementSetAttribute },
		{ "ElementSetProperty", lElementSetProperty },
		{ "ElementSetPropertyImmediate", lElementSetPropertyImmediate },
		{ "ElementSetPseudoClass", lElementSetPseudoClass },
		{ "ElementProject", lElementProject },
		{ "RenderBegin", lRenderBegin },
		{ "RenderFrame", lRenderFrame },
		{ "RmlInitialise", lRmlInitialise },
		{ "RmlShutdown", lRmlShutdown },
		{ "RmlRegisterEevent", lRmlRegisterEevent },
		{ "RmlTimeUpdate", lRmlTimeUpdate },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
