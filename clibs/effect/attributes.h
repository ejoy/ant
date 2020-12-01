#pragma once

#include "particle.h"

struct lua_State;
extern std::function<component_id (lua_State *, int)> find_attrib_reader(const std::string &name);

