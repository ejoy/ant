#include <lua.hpp>

#include <binding/Context.h>
#include <binding/ContextImpl.h>
#include <core/Document.h>
#include <core/Element.h>
#include <core/Text.h>
#include <core/Texture.h>
#include <util/HtmlParser.h>
#include <bee/nonstd/unreachable.h>

#include <string.h>
#include "fastio.h"

template <typename T>
T* lua_checkobject(lua_State* L, int idx) {
	luaL_checktype(L, idx, LUA_TLIGHTUSERDATA);
	return static_cast<T*>(lua_touserdata(L, idx));
}

static std::string_view
lua_checkstrview(lua_State* L, int idx) {
	size_t sz = 0;
	const char* str = luaL_checklstring(L, idx, &sz);
	return std::string_view(str, sz);
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

static int
lua_pushRmlNode(lua_State* L, const Rml::Node* node) {
	lua_pushlightuserdata(L, const_cast<Rml::Node*>(node));
	lua_pushinteger(L, (lua_Integer)node->GetType());
	return 2;
}

namespace {

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
lDocumentParseHtml(lua_State* L) {
	auto path = lua_checkstrview(L, 1);
	auto data = getmemory(L, 2);
	bool inner = lua_toboolean(L, 3);
	auto html = (Rml::HtmlElement*)lua_newuserdatauv(L, sizeof(Rml::HtmlElement), 0);
	new (html) Rml::HtmlElement;
	if (Rml::ParseHtml(path, data, inner, *html)) {
		return 1;
	}
	return 0;
}

static int
lDocumentInstanceHead(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	auto html = (Rml::HtmlElement*)lua_touserdata(L, 2);
	lua_newtable(L);
	lua_Integer n = 0;
	doc->InstanceHead(*html, [&](Rml::HtmlHead type, const std::string& str, int line) {
		lua_createtable(L, 3, 0);
		switch (type) {
		case Rml::HtmlHead::Script:
			lua_pushstring(L, "script");
			lua_seti(L, -2, 1);
			break;
		case Rml::HtmlHead::Style:
			lua_pushstring(L, "style");
			lua_seti(L, -2, 1);
			break;
		default:
			std::unreachable();
		}
		lua_pushlstring(L, str.data(), str.size());
		lua_seti(L, -2, 2);
		if (line >= 0) {
			lua_pushinteger(L, line);
			lua_seti(L, -2, 3);
		}
		lua_seti(L, -2, ++n);
	});
	return 1;
}

static int
lDocumentInstanceBody(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	auto html = (Rml::HtmlElement*)lua_touserdata(L, 2);
	doc->InstanceBody(*html);
	return 0;
}

static int
lDocumentLoadStyleSheet(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	switch (lua_gettop(L)) {
	case 1:
	case 2: {
		auto path = lua_checkstrview(L, 2);
		bool ok = doc->LoadStyleSheet(path);
		lua_pushboolean(L, ok);
		return 1;
	}
	case 3: {
		auto path = lua_checkstrview(L, 2);
		auto data = getmemory(L, 3);
		doc->LoadStyleSheet(path, data);
		return 0;
	}
	default:
	case 4: {
		auto path = lua_checkstrview(L, 2);
		auto data = getmemory(L, 3);
		auto line = luaL_checkinteger(L, 4);
		doc->LoadStyleSheet(path, data, (int)line);
		return 0;
	}
	}
	return 0;
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
	float delta = (float)luaL_checknumber(L, 2);
	doc->Update(delta / 1000);
	return 0;
}

static int
lDocumentFlush(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	doc->Flush();
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

static int
lDocumentCreateElement(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	Rml::Element* e = doc->CreateElement(lua_checkstdstring(L, 2));
	if (!e) {
		return 0;
	}
	e->NotifyCreated();
	lua_pushlightuserdata(L, e);
	return 1;
}

static int
lDocumentCreateTextNode(lua_State* L) {
	Rml::Document* doc = lua_checkobject<Rml::Document>(L, 1);
	Rml::Text* e = doc->CreateTextNode(lua_checkstdstring(L, 2));
	if (!e) {
		return 0;
	}
	lua_pushlightuserdata(L, e);
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
lElementGetScrollLeft(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushnumber(L, e->GetScrollLeft());
	return 1;
}

static int
lElementGetScrollTop(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushnumber(L, e->GetScrollTop());
	return 1;
}

static int
lElementSetScrollLeft(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetScrollLeft((float)luaL_checknumber(L, 2));
	return 0;
}

static int
lElementSetScrollTop(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetScrollTop((float)luaL_checknumber(L, 2));
	return 0;
}

static int
lElementSetScrollInsets(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::EdgeInsets<float> insets = {
		(float)luaL_checknumber(L, 2),
		(float)luaL_checknumber(L, 3),
		(float)luaL_checknumber(L, 4),
		(float)luaL_checknumber(L, 5),
	};
	e->SetScrollInsets(insets);
	return 0;
}

static int
lElementGetInnerHTML(lua_State *L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushstdstring(L, e->GetInnerHTML());
	return 1;
}

static int
lElementSetInnerHTML(lua_State *L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetInnerHTML(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementGetOuterHTML(lua_State *L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushstdstring(L, e->GetOuterHTML());
	return 1;
}

static int
lElementSetOuterHTML(lua_State *L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetOuterHTML(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementGetId(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushstdstring(L, e->GetId());
	return 1;
}

static int
lElementGetClassName(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushstdstring(L, e->GetClassName());
	return 1;
}

static int
lElementGetAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const std::string* attr = e->GetAttribute(lua_checkstdstring(L, 2));
	if (!attr) {
		return 0;
	}
	lua_pushstdstring(L, *attr);
	return 1;
}

static int
lElementGetAttributes(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const auto& attrs = e->GetAttributes();
	lua_createtable(L, 0, (int)attrs.size());
	for (const auto& [k, v]: attrs) {
		lua_pushstdstring(L, k);
		lua_pushstdstring(L, v);
		lua_rawset(L, -3);
	}
	return 1;
}

static int
lElementGetBounds(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	const Rml::Rect& bounds = e->GetBounds();
	lua_pushnumber(L, bounds.origin.x);
	lua_pushnumber(L, bounds.origin.y);
	lua_pushnumber(L, bounds.size.w);
	lua_pushnumber(L, bounds.size.h);
	return 4;
}

static int
lElementGetTagName(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushstdstring(L, e->GetTagName());
	return 1;
}

static int
lElementAppendChild(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Element* child = lua_checkobject<Rml::Element>(L, 2);
	auto index = (size_t)luaL_optinteger(L, 3, e->GetNumChildNodes());
	e->AppendChild(child, index);
	return 0;
}

static int
lElementInsertBefore(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Node* child = lua_checkobject<Rml::Node>(L, 2);
	Rml::Node* adjacent = lua_checkobject<Rml::Node>(L, 3);
	e->InsertBefore(child, adjacent);
	return 0;
}

static int
lElementGetPreviousSibling(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_pushRmlNode(L, e->GetPreviousSibling());
	return 2;
}

static int
lElementRemoveChild(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Element* child = lua_checkobject<Rml::Element>(L, 2);
	e->RemoveChild(child);
	return 0;
}

static int
lElementRemoveAllChildren(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveAllChildren();
	return 0;
}

static int
lElementGetChildren(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	if (lua_type(L, 2) != LUA_TNUMBER) {
		lua_pushinteger(L, e->GetNumChildNodes());
		return 1;
	}
	Rml::Node* child = e->GetChildNode((size_t)luaL_checkinteger(L, 2));
	if (child) {
		return lua_pushRmlNode(L, child);
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
lElementGetProperty(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	std::optional<std::string> prop = e->GetProperty(lua_checkstrview(L, 2));
	if (!prop) {
		return 0;
	}
	lua_pushstdstring(L, *prop);
	return 1;
}

static int
lElementRemoveAttribute(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->RemoveAttribute(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementSetId(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetId(lua_checkstdstring(L, 2));
	return 0;
}

static int
lElementSetClassName(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->SetClassName(lua_checkstdstring(L, 2));
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
	std::string_view name = lua_checkstrview(L, 2);
	if (lua_isnoneornil(L, 3)) {
		e->DelProperty(name);
	}
	else {
		std::string_view value = lua_checkstrview(L, 3);
		e->SetProperty(name, value);
	}
	return 0;
}

static int
lElementSetVisible(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	bool visible = lua_toboolean(L, 2);
	e->SetVisible(visible);
	return 0;
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
lElementDirtyImage(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	e->DirtyBackground();
	return 0;
}

static int
lElementDelete(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	delete e;
	return 0;
}

static int
lElementGetElementById(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	Rml::Element* element = e->GetElementById(lua_checkstdstring(L, 2));
	if (!element) {
		return 0;
	}
	lua_pushlightuserdata(L, element);
	return 1;
}

static int
lElementGetElementsByTagName(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_newtable(L);
	lua_Integer i = 0;
	e->GetElementsByTagName(lua_checkstdstring(L, 2), [&](Rml::Element* child) {
		lua_pushlightuserdata(L, child);
		lua_seti(L, -2, ++i);
	});
	return 1;
}

static int
lElementGetElementsByClassName(lua_State* L) {
	Rml::Element* e = lua_checkobject<Rml::Element>(L, 1);
	lua_newtable(L);
	lua_Integer i = 0;
	e->GetElementsByClassName(lua_checkstdstring(L, 2), [&](Rml::Element* child) {
		lua_pushlightuserdata(L, child);
		lua_seti(L, -2, ++i);
	});
	return 1;
}

static int
lNodeGetParent(lua_State* L) {
	Rml::Node* e = lua_checkobject<Rml::Node>(L, 1);
	Rml::Element* parent = e->GetParentNode();
	if (!parent) {
		return 0;
	}
	lua_pushlightuserdata(L, parent);
	return 1;
}

static int
lNodeClone(lua_State* L) {
	Rml::Node* e = lua_checkobject<Rml::Node>(L, 1);
	Rml::Node* r = e->Clone();
	if (!r) {
		return 0;
	}
	return lua_pushRmlNode(L, r);
}

static int
lTextGetText(lua_State* L) {
	Rml::Text* e = lua_checkobject<Rml::Text>(L, 1);
	lua_pushstdstring(L, e->GetText());
	return 1;
}

static int
lTextSetText(lua_State* L) {
	Rml::Text* e = lua_checkobject<Rml::Text>(L, 1);
	e->SetText(lua_checkstdstring(L, 2));
	return 0;
}

static int
lTextDelete(lua_State* L) {
	Rml::Text* e = lua_checkobject<Rml::Text>(L, 1);
	delete e;
	return 0;
}

static int
lRmlInitialise(lua_State* L) {
    if (!Rml::Initialise(L, 1)){
        return luaL_error(L, "Failed to Initialise RmlUi.");
    }
    return 0;
}

static int
lRmlShutdown(lua_State* L) {
    Rml::Shutdown();
    return 0;
}

static int
lRenderBegin(lua_State* L) {
	Rml::GetRender()->Begin();
	return 0;
}

static int
lRenderFrame(lua_State* L) {
	Rml::GetRender()->End();
    return 0;
}

static int
lRenderSetTexture(lua_State* L) {
	Rml::TextureData data;
	if (lua_gettop(L) >= 4) {
		data.handle = (Rml::TextureId)luaL_checkinteger(L, 2);
		data.dimensions.w = (float)luaL_checkinteger(L, 3);
		data.dimensions.h = (float)luaL_checkinteger(L, 4);
	}
	Rml::Texture::Set(lua_checkstdstring(L, 1), std::move(data));
    return 0;
}

}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int
luaopen_rmlui(lua_State* L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "DocumentCreate", lDocumentCreate },
		{ "DocumentParseHtml", lDocumentParseHtml },
		{ "DocumentInstanceHead", lDocumentInstanceHead },
		{ "DocumentInstanceBody", lDocumentInstanceBody },
		{ "DocumentLoadStyleSheet", lDocumentLoadStyleSheet },
		{ "DocumentDestroy", lDocumentDestroy },
		{ "DocumentUpdate", lDocumentUpdate },
		{ "DocumentFlush", lDocumentFlush },
		{ "DocumentSetDimensions", lDocumentSetDimensions},
		{ "DocumentElementFromPoint", lDocumentElementFromPoint },
		{ "DocumentGetBody", lDocumentGetBody },
		{ "DocumentCreateElement", lDocumentCreateElement },
		{ "DocumentCreateTextNode", lDocumentCreateTextNode },
		{ "ElementGetId", lElementGetId },
		{ "ElementGetClassName", lElementGetClassName },
		{ "ElementGetAttribute", lElementGetAttribute },
		{ "ElementGetAttributes", lElementGetAttributes },
		{ "ElementGetBounds", lElementGetBounds },
		{ "ElementGetTagName", lElementGetTagName },
		{ "ElementGetChildren", lElementGetChildren },
		{ "ElementGetOwnerDocument", lElementGetOwnerDocument },
		{ "ElementGetProperty", lElementGetProperty },
		{ "ElementRemoveAttribute", lElementRemoveAttribute },
		{ "ElementSetId", lElementSetId },
		{ "ElementSetClassName", lElementSetClassName },
		{ "ElementSetAttribute", lElementSetAttribute },
		{ "ElementSetProperty", lElementSetProperty },
		{ "ElementSetVisible", lElementSetVisible },
		{ "ElementSetPseudoClass", lElementSetPseudoClass },
		{ "ElementGetScrollLeft", lElementGetScrollLeft },
		{ "ElementGetScrollTop", lElementGetScrollTop },
		{ "ElementSetScrollLeft", lElementSetScrollLeft },
		{ "ElementSetScrollTop", lElementSetScrollTop },
		{ "ElementSetScrollInsets", lElementSetScrollInsets },
		{ "ElementGetInnerHTML", lElementGetInnerHTML },
		{ "ElementSetInnerHTML", lElementSetInnerHTML },
		{ "ElementGetOuterHTML", lElementGetOuterHTML },
		{ "ElementSetOuterHTML", lElementSetOuterHTML },
		{ "ElementAppendChild", lElementAppendChild },
		{ "ElementInsertBefore", lElementInsertBefore },
		{ "ElementGetPreviousSibling", lElementGetPreviousSibling },
		{ "ElementRemoveChild", lElementRemoveChild },
		{ "ElementRemoveAllChildren", lElementRemoveAllChildren},
		{ "ElementGetElementById", lElementGetElementById },
		{ "ElementGetElementsByTagName", lElementGetElementsByTagName },
		{ "ElementGetElementsByClassName", lElementGetElementsByClassName },
		{ "ElementDelete", lElementDelete },
		{ "ElementProject", lElementProject },
		{ "ElementDirtyImage", lElementDirtyImage },
		{ "NodeGetParent", lNodeGetParent },
		{ "NodeClone", lNodeClone },
		{ "TextGetText", lTextGetText },
		{ "TextSetText", lTextSetText },
		{ "TextDelete", lTextDelete },
		{ "RenderBegin", lRenderBegin },
		{ "RenderFrame", lRenderFrame },
		{ "RenderSetTexture", lRenderSetTexture },
		{ "RmlInitialise", lRmlInitialise },
		{ "RmlShutdown", lRmlShutdown },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
