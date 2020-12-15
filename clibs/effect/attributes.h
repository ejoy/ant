#pragma once

#include "particle.h"

struct lua_State;
class particle_emitter;
using readerop = std::function<void (lua_State *, int, particle_emitter*, comp_ids&)>;
readerop find_attrib_reader(const std::string &name);

