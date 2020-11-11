#include "pch.h"

// Notice: I need call Context::GetDataModelPtr directly
#define private public
#include <RmlUi/Core/Context.h>
#undef private

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include "luaplugin.h"

#include <RmlUi/Core/DataModelHandle.h>
#include <RmlUi/Core/DataVariable.h>
#include <RmlUi/Core/Element.h>
#include <RmlUi/Core/ElementDocument.h>

#define RMLDATAMODEL "RMLDATAMODEL"

void
lua_pushvariant(lua_State *L, const Rml::Variant &v) {
	switch (v.GetType()) {
	case Rml::Variant::Type::BOOL:
		lua_pushboolean(L, v.GetReference<bool>());
		break;
	case Rml::Variant::Type::BYTE:
	case Rml::Variant::Type::CHAR:
	case Rml::Variant::Type::INT:
		lua_pushinteger(L, v.GetReference<int>());
		break;
	case Rml::Variant::Type::FLOAT:
		lua_pushnumber(L, v.GetReference<float>());
		break;
	case Rml::Variant::Type::DOUBLE:
		lua_pushnumber(L, v.GetReference<double>());
		break;
	case Rml::Variant::Type::INT64:
		lua_pushinteger(L, v.GetReference<int64_t>());
		break;
	case Rml::Variant::Type::STRING: {
		const Rml::String &s = v.GetReference<Rml::String>();
		lua_pushlstring(L, s.c_str(), s.length());
		break; }
	case Rml::Variant::Type::NONE:
	case Rml::Variant::Type::VECTOR2:
	case Rml::Variant::Type::VECTOR3:
	case Rml::Variant::Type::VECTOR4:
	case Rml::Variant::Type::COLOURF:
	case Rml::Variant::Type::COLOURB:
	case Rml::Variant::Type::SCRIPTINTERFACE:
	case Rml::Variant::Type::TRANSFORMPTR:
	case Rml::Variant::Type::TRANSITIONLIST:
	case Rml::Variant::Type::ANIMATIONLIST:
	case Rml::Variant::Type::DECORATORSPTR:
	case Rml::Variant::Type::FONTEFFECTSPTR:
	case Rml::Variant::Type::VOIDPTR:
	default:
		// todo
		lua_pushnil(L);
		break;
	}
}

void
lua_getvariant(lua_State *L, int index, Rml::Variant* variant) {
	if (!variant)
		return;
	switch(lua_type(L, index)) {
	case LUA_TBOOLEAN:
		*variant = (bool)lua_toboolean(L, index);
		break;
	case LUA_TNUMBER:
		if (lua_isinteger(L, index)) {
			*variant = (int64_t)lua_tointeger(L, index);
		} else {
			*variant = (double)lua_tonumber(L, index);
		}
		break;
	case LUA_TSTRING:
		*variant = Rml::String(lua_tostring(L, index));
		break;
	case LUA_TNIL:
	default:	// todo
		*variant = Rml::Variant();
		break;
	}
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

static int
lElementGetInnerRML(lua_State *L) {
	Rml::Element *e = (Rml::Element *)lua_touserdata(L, 1);
	const Rml::String &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

class LuaScalarDef;

struct LuaDataModel {
	Rml::DataModelHandle handle;
	lua_State *dataL;
	LuaScalarDef *scalarDef;
};

class LuaScalarDef final : public Rml::VariableDefinition {
public:
	LuaScalarDef (const struct LuaDataModel *model) :
		VariableDefinition(Rml::DataVariableType::Scalar), model(model) {}
private:
	virtual bool Get(void* ptr, Rml::Variant& variant) {
		lua_State *L = model->dataL;
		if (!L)
			return false;
		int id = (intptr_t)ptr;
		lua_getvariant(L, id, &variant);
		return true;
	}
	virtual bool Set(void* ptr, const Rml::Variant& variant) {
		int id = (intptr_t)ptr;
		lua_State *L = model->dataL;
		if (!L)
			return false;
		lua_pushvariant(L, variant);
		lua_replace(L, id);
		return true;
	}

	const struct LuaDataModel *model;
};

static int
getId(lua_State *L, lua_State *dataL) {
	lua_pushvalue(dataL, 1);
	lua_xmove(dataL, L, 1);
	lua_pushvalue(L, 2);
	if (lua_rawget(L, -2) != LUA_TNUMBER) {
		luaL_error(L, "DataModel has no key : %s", lua_tostring(L, 2));
	}
	int id = lua_tointeger(L, -1);
	lua_pop(L, 2);
	return id;
}

static int
lDataModelGet(lua_State *L) {
	struct LuaDataModel *D = (struct LuaDataModel *)lua_touserdata(L, 1);
	lua_State *dataL = D->dataL;
	if (dataL == NULL)
		luaL_error(L, "DataModel released");

	int id = getId(L, dataL);
	lua_pushvalue(dataL, id);
	lua_xmove(dataL, L, 1);
	return 1;
}

static int
lDataModelSet(lua_State *L) {
	struct LuaDataModel *D = (struct LuaDataModel *)lua_touserdata(L, 1);
	lua_State *dataL = D->dataL;
	if (dataL == NULL)
		luaL_error(L, "DataModel released");
	int id = getId(L, dataL);
	lua_xmove(L, dataL, 1);
	lua_replace(dataL, id);
	D->handle.DirtyVariable(lua_tostring(L, 2));
	return 0;
}

// We should release LuaDataModel manually
static int
lDataModelRelease(lua_State *L) {
	struct LuaDataModel *D = (struct LuaDataModel *)luaL_checkudata(L, 1, RMLDATAMODEL);

	D->dataL = nullptr;
	delete D->scalarDef;
	D->scalarDef = nullptr;
	lua_pushnil(L);
	lua_setuservalue(L, -2);
	return 0;
}

// Construct a lua sub thread for LuaDataModel
// stack 1 : { name(string) -> id(integer) }
// stack 2- : values
// For example : build from { str = "Hello", x = 0 }
//	1: { str = 2 , x = 3 }
//	2: "Hello"
//	3: 0
static lua_State *
InitDataModelFromTable(lua_State *L, int index, Rml::DataModelConstructor &ctor, class LuaScalarDef *def) {
	lua_State *dataL = lua_newthread(L);
	lua_newtable(dataL);
	intptr_t id = 2;
	lua_pushnil(L);
	while (lua_next(L, index) != 0) {
		if (!lua_checkstack(dataL, 4)) {
			luaL_error(L, "Memory Error");
		}
		// L top : key value
		lua_xmove(L, dataL, 1);	// move value to dataL with index(id)
		lua_pushvalue(L, -1);	// dup key
		lua_xmove(L, dataL, 1);
		lua_pushinteger(dataL, id);
		lua_rawset(dataL, 1);
		const char *key = lua_tostring(L, -1);
		ctor.BindCustomDataVariable(key, Rml::DataVariable(def, (void *)id));
		++id;
	}
	return dataL;
}

static int
lDataModelCreate(lua_State *L) {
	Rml::Context *context = (Rml::Context *)lua_touserdata(L, 1);
	Rml::String name = luaL_checkstring(L, 2);
	luaL_checktype(L, 3, LUA_TTABLE);

	Rml::DataModelConstructor constructor = context->CreateDataModel(name);
	if (!constructor) {
		return luaL_error(L, "Can't create DataModel with name %s", name.c_str());
	}

	struct LuaDataModel *D = (struct LuaDataModel *)lua_newuserdata(L, sizeof(*D));
	D->dataL = nullptr;
	D->scalarDef = nullptr;
	D->handle = constructor.GetModelHandle();

	D->scalarDef = new LuaScalarDef(D);
	D->dataL = InitDataModelFromTable(L, 3, constructor, D->scalarDef);
	lua_setuservalue(L, -2);

	if (luaL_newmetatable(L, RMLDATAMODEL)) {
		luaL_Reg l[] = {
			{ "__index", lDataModelGet },
			{ "__newindex", lDataModelSet },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);

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
		{ "DataModelRelease", lDataModelRelease },
		{ "DataModelCreate", lDataModelCreate },
		{ "DocumentGetContext", lDocumentGetContext },
		{ "DocumentGetTitle", lDocumentGetTitle },
		{ "DocumentGetSourceURL", lDocumentGetSourceURL },
		{ "DocumentShow", lDocumentShow },
		{ "ElementGetInnerRML", lElementGetInnerRML },
		{ "Log", lLog },
		{ "RmlCreateContext", lRmlCreateContext },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}

