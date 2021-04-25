#pragma once

#if __has_include(<filesystem>)
#   if defined(__MINGW32__)
#       if __GNUC__ > 9 || (__GNUC__ == 9 && __GNUC_MINOR__ >= 2)
#           define ANT_ENABLE_FILESYSTEM 1
#       endif
#   elif defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
#       if __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ >= 101500
#           define ANT_ENABLE_FILESYSTEM 1
#       endif
#   elif defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__)
#       if __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__ >= 130000
#           define ANT_ENABLE_FILESYSTEM 1
#       endif
#   else
#       define ANT_ENABLE_FILESYSTEM 1
#   endif
#endif

#if defined(ANT_ENABLE_FILESYSTEM)
#undef ANT_ENABLE_FILESYSTEM
#include <filesystem>
namespace fs = std::filesystem;
#else
#error "compiler does not support filesystem"
#endif
