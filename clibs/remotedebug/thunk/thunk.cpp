#include "thunk.h"

#if defined(_WIN32)
#	include "thunk_windows.inl"
#	if defined(_M_X64)
#		include "thunk_windows_amd64.inl"
#	else
#		include "thunk_windows_i386.inl"
#	endif
#elif defined(__linux__) || defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
#	include "thunk_linux.inl"
#else
#	include "thunk_other.inl"
#endif
