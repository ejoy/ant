#pragma once

#if defined(USE_DYNARRAY)
#include "dynarray.h"
#else
#include <vector>
namespace std { template<class T> using dynarray = ::std::vector<T>; }
#endif

#if defined(_WIN32)
#include "subprocess_win.h"
namespace base { namespace subprocess = win::subprocess; }
#else
#include "subprocess_posix.h"
namespace base { namespace subprocess = posix::subprocess; }
#endif

