#pragma once

#if defined(_WIN32)
#include "subprocess_win.h"
namespace base { namespace subprocess = win::subprocess; }
#else
#include "subprocess_posix.h"
namespace base { namespace subprocess = posix::subprocess; }
#endif

