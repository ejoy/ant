#ifndef ant_rml_lua_plugin_h
#define ant_rml_lua_plugin_h

void lua_plugin_register(lua_State *L, int index);
int lua_plugin_apis(lua_State *L);
void lua_pushvariant(lua_State *L, const Rml::Variant &v);

#endif
