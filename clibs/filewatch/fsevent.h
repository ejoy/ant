#pragma once

#if defined(_WIN32)
#include "fsevent_win.h"
namespace ant { namespace fsevent = win::fsevent; }
#endif
