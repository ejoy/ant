#pragma once

#include <lua.hpp>

#if defined(_WIN32)
#include <wchar.h>
#define RT_COMMAND wchar_t**
#else
#define RT_COMMAND char**
#endif

void runtime_main(int argc, RT_COMMAND argv, void(*errfunc)(const char*));
