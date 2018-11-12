#pragma once

#include <map>
#include <string>
#include <lua.hpp>

std::map<std::string, lua_CFunction> preload_module();