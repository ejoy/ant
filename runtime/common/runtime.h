#pragma once

#include <lua.hpp>

extern "C" void runtime_main(int argc, char** argv, void(*errfunc)(const char*));
