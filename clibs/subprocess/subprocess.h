#pragma once

#if defined(_WIN32)
#include "subprocess_win.h"
namespace ant { namespace subprocess = win::subprocess; }
#else
#include "subprocess_posix.h"
namespace ant { namespace subprocess = posix::subprocess; }
#endif

