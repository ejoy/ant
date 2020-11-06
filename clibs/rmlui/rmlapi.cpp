// Notice: I need call Context::GetDataModelPtr directly
#define private public
#include <RmlUi/Core/Context.h>
#undef private

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include "luaplugin.h"

#include <RmlUi/Core/DataModel.h>
#include <RmlUi/Core/DataVariable.h>
#include <RmlUi/Core/Element.h>
#include <RmlUi/Core/ElementDocument.h>

#define DMTABLE "DMTABLE"

void
lua_pushvariant(lua_State *L, const Rml::Variant &v) {
	switch (v.GetType()) {
	case Rml::Variant::Type::BOOL:
		lua_pushboolean(L, v.GetReference<bool>());
		break;
	case Rml::Variant::Type::BYTE:
		lua_pushinteger(L, v.GetReference<unsigned char>());
		break;
	case Rml::Variant::Type::CHAR: {
		char s[1] = {v.GetReference<char>() };
		lua_pushlstring(L, s, 1);
		break; }
	case Rml::Variant::Type::FLOAT:
		lua_pushnumber(L, v.GetReference<float>());
		break;
	case Rml::Variant::Type::DOUBLE:
		lua_pushnumber(L, v.GetReference<double>());
		break;
	case Rml::Variant::Type::INT:
		lua_pushinteger(L, v.GetReference<int>());
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

namespace {

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
lElementGetInnerRML(lua_State *L) {
	Rml::Element *e = (Rml::Element *)lua_touserdata(L, 1);
	const Rml::String &rml = e->GetInnerRML();
	lua_pushlstring(L, rml.c_str(), rml.length());
	return 1;
}

class lua_scalar;

struct lua_datamodel {
	Rml::DataModel *model;
	lua_State *dataL;
	lua_scalar *scalar_def;
};

class lua_scalar final : public Rml::VariableDefinition {
public:
	lua_scalar (struct lua_datamodel *model) :
		VariableDefinition(Rml::DataVariableType::Scalar), model(model) {}
private:
	virtual bool Get(void* ptr, Rml::Variant& variant) {
		lua_State *L = model->dataL;
		if (!L)
			return false;
		int id = (intptr_t)ptr;
		switch(lua_type(L, id)) {
		case LUA_TBOOLEAN:
			variant = (bool)lua_toboolean(L, id);
			break;
		case LUA_TNUMBER:
			if (lua_isinteger(L, id)) {
				variant = (int64_t)lua_tointeger(L, id);
			} else {
				variant = (double)lua_tonumber(L, id);
			}
			break;
		case LUA_TSTRING:
			variant = Rml::String(lua_tostring(L, id));
			break;
		case LUA_TNIL:
		default:	// todo
			variant = Rml::Variant();
			break;
		}
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

	struct lua_datamodel *model;
};

static int
get_id(lua_State *L, lua_State *dataL) {
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
ldatamodel_get(lua_State *L) {
	struct lua_datamodel *dm = (struct lua_datamodel *)lua_touserdata(L, 1);
	lua_State *dataL = dm->dataL;
	if (dataL == NULL)
		luaL_error(L, "DataModel released");

	int id = get_id(L, dataL);
	lua_pushvalue(dataL, id);
	lua_xmove(dataL, L, 1);
	return 1;
}

static int
ldatamodel_set(lua_State *L) {
	struct lua_datamodel *dm = (struct lua_datamodel *)lua_touserdata(L, 1);
	lua_State *dataL = dm->dataL;
	if (dataL == NULL)
		luaL_error(L, "DataModel released");
	int id = get_id(L, dataL);
	lua_xmove(L, dataL, 1);
	lua_replace(dataL, id);
	dm->model->DirtyVariable(lua_tostring(L, 2));
	return 0;
}

// We should release lua_datamodel manually
static int
lDataModelRelease(lua_State *L) {
	struct lua_datamodel *dm = (struct lua_datamodel *)lua_touserdata(L, 1);
	delete dm->scalar_def;
	dm->model = nullptr;
	dm->scalar_def = nullptr;
	dm->dataL = nullptr;
	lua_pushnil(L);
	lua_setuservalue(L, 1);
	return 0;
}

static lua_State *
bind_table(lua_State *L, int index, struct lua_datamodel *model) {
	model->scalar_def = new lua_scalar(model);
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
		model->model->BindVariable(key, Rml::DataVariable(model->scalar_def, (void *)id)); 
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

	struct lua_datamodel *dm = (struct lua_datamodel *)lua_newuserdata(L, sizeof(*dm));
	dm->model = context->GetDataModelPtr(name);
	dm->dataL = nullptr;
	dm->scalar_def = nullptr;
	
	dm->dataL = bind_table(L, 3, dm);
	lua_setuservalue(L, -2);

	if (luaL_newmetatable(L, "RMLDATAMODEL")) {
		luaL_Reg l[] = {
			{ "__index", ldatamodel_get },
			{ "__newindex", ldatamodel_set },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, l, 0);
	}
	lua_setmetatable(L, -2);

	return 1;
}

static int
lDataModelUpdate(lua_State *L) {
	struct lua_datamodel *dm = (struct lua_datamodel *)lua_touserdata(L, 1);
	if (dm->model) {
		dm->model->Update();
	}
	return 0;
}

}

int
lua_plugin_apis(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "DataModelRelease", lDataModelRelease },
		{ "DataModelCreate", lDataModelCreate },
		{ "DataModelUpdate", lDataModelUpdate },
		{ "DocumentGetContext", lDocumentGetContext },
		{ "DocumentGetTitle", lDocumentGetTitle },
		{ "DocumentGetSourceURL", lDocumentGetSourceURL },
		{ "ElementGetInnerRML", lElementGetInnerRML },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	// create datamodel
	lua_newtable(L);
	lua_setfield(L, LUA_REGISTRYINDEX, DMTABLE);

	return 1;
}

