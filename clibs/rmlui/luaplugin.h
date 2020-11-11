#ifndef ant_rml_lua_plugin_h
#define ant_rml_lua_plugin_h

struct lua_State;

typedef void* plugin_t;

plugin_t lua_plugin_create(lua_State* L, int index);
void lua_plugin_call(plugin_t plugin, const char* name, size_t argn = 0, size_t retn = 0);
lua_State* lua_plugin_getlua(plugin_t plugin);
void lua_plugin_destroy(plugin_t plugin);

int lua_plugin_apis(lua_State *L);
void lua_pushvariant(lua_State *L, const Rml::Variant &v);
void lua_getvariant(lua_State *L, int index, Rml::Variant* variant);

#endif
