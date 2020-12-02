#pragma once

#include "particle.h"

struct lua_State;
extern std::function<void (lua_State *, int, comp_ids&)> find_attrib_reader(const std::string &name);

