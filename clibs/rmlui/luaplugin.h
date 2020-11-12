#ifndef ant_rml_lua_plugin_h
#define ant_rml_lua_plugin_h

struct lua_State;

Rml::Plugin* lua_plugin_create();
void lua_plugin_init(Rml::Plugin* plugin, lua_State* L, const char* source, size_t sz);
void lua_plugin_call(lua_State* L, const char* name, size_t argn = 0, size_t retn = 0);
void lua_plugin_destroy(Rml::Plugin* plugin);

int lua_plugin_apis(lua_State *L);
void lua_pushvariant(lua_State *L, const Rml::Variant &v);
void lua_getvariant(lua_State *L, int index, Rml::Variant* variant);

#endif
