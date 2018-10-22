#pragma once

#if defined(USE_DYNARRAY)
#include "dynarray.h"
#else
#include <vector>
namespace std { template<class T> using dynarray = ::std::vector<T>; }
#endif

#if defined(_WIN32)
#    include "subprocess_win.h"
#else
#    include "subprocess_posix.h"
#endif
