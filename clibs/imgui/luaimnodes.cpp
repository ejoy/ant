#define LUA_LIB

extern "C" {
#include <lua.h>
#include <lauxlib.h>
}

#include <imgui.h>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <cstdint>
#include <unordered_map>

#include <imnodes.h>

//todo use common header
// enums
struct enum_pair {
	const char* name;
	lua_Integer value;
};

#define NODE_ENUM(prefix, name) { #name, imnodes::prefix##_##name }

static void
enum_gen(lua_State* L, const char* name, struct enum_pair* enums) {
	int i;
	lua_newtable(L);
	for (i = 0; enums[i].name; i++) {
		lua_pushinteger(L, enums[i].value);
		lua_setfield(L, -2, enums[i].name);
	}
	lua_setfield(L, -2, name);
}


static int
nInitialize(lua_State* L) {
	imnodes::Initialize();
	return 0;
}

static int
nShutdown(lua_State* L) {
	imnodes::Shutdown();
	return 0;
}

static int
nBeginNodeEditor(lua_State* L) {
	imnodes::BeginNodeEditor();
	return 0;
}

static int
nEndNodeEditor(lua_State* L) {
	imnodes::EndNodeEditor();
	return 0;
}

static int
nBeginNode(lua_State* L) {
	int id = (int)luaL_checkinteger(L, 1);
	imnodes::BeginNode(id);
	return 0;
}

static int
nEndNode(lua_State* L) {
	imnodes::EndNode();
	return 0;
}

static int
nBeginNodeTitleBar(lua_State* L) {
	imnodes::BeginNodeTitleBar();
	return 0;
}

static int
nEndNodeTitleBar(lua_State* L) {
	imnodes::EndNodeTitleBar();
	return 0;
}

static int
nBeginInputAttribute(lua_State* L) {
	int id = (int)luaL_checkinteger(L, 1);
	int shape = (int)luaL_optinteger(L, 2, 0);//0=circle
	imnodes::BeginInputAttribute(id, (imnodes::PinShape)shape);
	return 0;
}

static int
nEndAttribute(lua_State* L) {
	imnodes::EndAttribute();
	return 0;
}

static int
nBeginOutputAttribute(lua_State* L) {
	int id = (int)luaL_checkinteger(L, 1);
	int shape = (int)luaL_optinteger(L, 2, 0);//0=circle
	imnodes::BeginOutputAttribute(id, (imnodes::PinShape)shape);
	return 0;
}

static int
nLink(lua_State* L) {
	int id_link = (int)luaL_checkinteger(L, 1);
	int id_pin_start = (int)luaL_checkinteger(L, 2);
	int id_pin_end = (int)luaL_checkinteger(L, 3);
	imnodes::Link(id_link, id_pin_start, id_pin_end);
	return 0;
}

static int
nPushColorStyle(lua_State* L) {
	int colorStyle = (int)luaL_checkinteger(L, 1);
	float r = (float)luaL_checknumber(L, 2);
	float g = (float)luaL_checknumber(L, 3);
	float b = (float)luaL_checknumber(L, 4);
	float a = (float)luaL_optnumber(L, 5, 1.0f);
	imnodes::PushColorStyle((imnodes::ColorStyle)colorStyle, ImColor(r,g,b,a) );
	return 0;
}

static int
nPopColorStyle(lua_State* L) {
	int num = (int)luaL_optinteger(L, 1, 1);
	while (num-- > 0){
		imnodes::PopColorStyle();
	}
	return 0;
}

static int
nPushStyleVar(lua_State* L) {
	int style = (int)luaL_checkinteger(L, 1);
	float value = (float)luaL_checknumber(L, 2);
	imnodes::PushStyleVar((imnodes::StyleVar)style, value);
	return 0;
}

static int
nPopStyleVar(lua_State* L) {
	int num = (int)luaL_optinteger(L, 1, 1);
	while (num-- > 0) {
		imnodes::PopStyleVar();
	}
	return 0;
}

static int
nIsLinkCreated(lua_State* L) {
	int startPin, endPin;
	if (imnodes::IsLinkCreated(&startPin, &endPin)){
		lua_pushboolean(L, true);
		lua_pushinteger(L, startPin);
		lua_pushinteger(L, endPin);
		return 3;
	}
	else{
		lua_pushboolean(L, false);
		return 1;
	}
}

static int
nNumSelectedLinks(lua_State* L) {
	const int num = imnodes::NumSelectedLinks();
	lua_pushinteger(L, num);
	return 1;
}

static int
nGetSelectedLinks(lua_State* L) {
	const int num = imnodes::NumSelectedLinks();
	if (num > 0){
		lua_pushnil(L);
		return 1;
	}
	else {
		static std::vector<int> selected_links;
		selected_links.resize(static_cast<size_t>(num), -1);
		imnodes::GetSelectedLinks(selected_links.data());
		lua_newtable(L);
		for (int i = 0; i < selected_links.size(); i++) {
			lua_pushinteger(L, selected_links[i]);
			lua_rawseti(L, -2, (lua_Integer)i + 1);
		}
		return 1;
	}
}

static int
nNumSelectedNodes(lua_State* L) {
	const int num = imnodes::NumSelectedNodes();
	lua_pushinteger(L, num);
	return 1;
}

static int
nGetSelectedNodes(lua_State* L) {
	const int num = imnodes::NumSelectedNodes();
	if (num > 0) {
		lua_pushnil(L);
		return 1;
	}
	else {
		static std::vector<int> selected_nodes;
		selected_nodes.resize(static_cast<size_t>(num), -1);
		imnodes::GetSelectedNodes(selected_nodes.data());
		lua_newtable(L);
		for (int i = 0; i < selected_nodes.size(); i++) {
			lua_pushinteger(L, selected_nodes[i]);
			lua_rawseti(L, -2, (lua_Integer)i + 1);
		}
		return 1;
	}
}

static int
nSetNodeDraggable(lua_State* L) {
	int id = (int)luaL_checkinteger(L, 1);
	bool value = lua_toboolean(L, 2);
	imnodes::SetNodeDraggable(id,value);
	return 0;
}

static int
nSetNodeGridSpacePos(lua_State* L) {
	int id = (int)luaL_checkinteger(L, 1);
	float x = (float)lua_tonumber(L, 2);
	float y = (float)lua_tonumber(L, 3);
	imnodes::SetNodeGridSpacePos(id,  ImVec2(x, y));
	return 0;
}

static int
nSetNodeScreenSpacePos(lua_State* L) {
	int id = (int)luaL_checkinteger(L, 1);
	float x = (float)lua_tonumber(L, 2);
	float y = (float)lua_tonumber(L, 3);
	imnodes::SetNodeScreenSpacePos(id, ImVec2(x, y));
	return 0;
}

static struct enum_pair eStyleCol[] = {
	NODE_ENUM(ColorStyle, NodeBackground),
	NODE_ENUM(ColorStyle, NodeBackgroundHovered),
	NODE_ENUM(ColorStyle, NodeBackgroundSelected),
	NODE_ENUM(ColorStyle, NodeOutline),
	NODE_ENUM(ColorStyle, TitleBar),
	NODE_ENUM(ColorStyle, TitleBarHovered),
	NODE_ENUM(ColorStyle, TitleBarSelected),
	NODE_ENUM(ColorStyle, Link),
	NODE_ENUM(ColorStyle, LinkHovered),
	NODE_ENUM(ColorStyle, LinkSelected),
	NODE_ENUM(ColorStyle, Pin),
	NODE_ENUM(ColorStyle, PinHovered),
	NODE_ENUM(ColorStyle, BoxSelector),
	NODE_ENUM(ColorStyle, BoxSelectorOutline),
	NODE_ENUM(ColorStyle, GridBackground),
	NODE_ENUM(ColorStyle, GridLine),
	NODE_ENUM(ColorStyle, Count),
	{ NULL, 0 },
};

static struct enum_pair eStyleVar[] = {
	NODE_ENUM(StyleVar, GridSpacing),
	NODE_ENUM(StyleVar, NodeCornerRounding),
	NODE_ENUM(StyleVar, NodePaddingHorizontal),
	NODE_ENUM(StyleVar, NodePaddingVertical),
	{ NULL, 0 },
};

static struct enum_pair eStyleFlags[] = {
	NODE_ENUM(StyleVar, GridSpacing),
	NODE_ENUM(StyleVar, NodeCornerRounding),
	NODE_ENUM(StyleVar, NodePaddingHorizontal),
	NODE_ENUM(StyleVar, NodePaddingVertical),
	{ NULL, 0 },
};

static struct enum_pair ePinShape[] = {
	NODE_ENUM(PinShape,Circle),
	NODE_ENUM(PinShape,CircleFilled),
	NODE_ENUM(PinShape,Triangle),
	NODE_ENUM(PinShape,TriangleFilled),
	NODE_ENUM(PinShape,Quad),
	NODE_ENUM(PinShape,QuadFilled),
	{ NULL, 0 },
};

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int

luaopen_imnodes(lua_State* L) {
	luaL_Reg node[] = {
		{"Initialize",nInitialize},
		{"Shutdown", nShutdown },
		{"BeginNodeEditor", nBeginNodeEditor },
		{"EndNodeEditor", nEndNodeEditor },
		{"BeginNode", nBeginNode },
		{"EndNode", nEndNode },
		{"BeginNodeTitleBar", nBeginNodeTitleBar },
		{"EndNodeTitleBar", nEndNodeTitleBar },
		{"BeginInputAttribute", nBeginInputAttribute },
		{"EndAttribute", nEndAttribute },
		{"BeginOutputAttribute", nBeginOutputAttribute },
		{"EndAttribute", nEndAttribute },
		{"Link", nLink },
		{"PushStyleColor", nPushColorStyle },
		{"PopStyleColor", nPopColorStyle },
		{"PushStyleVar", nPushStyleVar },
		{"PopStyleVar", nPopStyleVar },
		{"IsLinkCreated", nIsLinkCreated },
		{"NumSelectedLinks", nNumSelectedLinks },
		{"GetSelectedLinks", nGetSelectedLinks },
		{"NumSelectedNodes", nNumSelectedNodes },
		{"GetSelectedNodes", nGetSelectedNodes },
		{"SetNodeDraggable", nSetNodeDraggable},
		{"SetNodeGridSpacePos", nSetNodeGridSpacePos},
		{"SetNodeScreenSpacePos", nSetNodeScreenSpacePos},
		{NULL,NULL}
	};
	luaL_newlib(L, node);

	lua_newtable(L);
	enum_gen(L, "StyleCol", eStyleCol);
	enum_gen(L, "StyleVar", eStyleVar);
	enum_gen(L, "StyleFlags", eStyleFlags);
	enum_gen(L, "PinShape", ePinShape);
	lua_setfield(L, -2, "enum");

	lua_setfield(L, -2, "node");
	return 1;
}
