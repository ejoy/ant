#pragma once

#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)

namespace remotedebug {
	void putenv(const char* envstr);
}

#endif
