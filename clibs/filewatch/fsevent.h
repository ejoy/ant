#pragma once

#if defined(_WIN32)
#include "fsevent_win.h"
namespace ant { namespace fsevent = win::fsevent; }
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#include "fsevent_osx.h"
namespace ant { namespace fsevent = osx::fsevent; }
#endif
