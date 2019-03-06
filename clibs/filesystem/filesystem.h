#pragma once

#if __has_include(<filesystem>) && !defined(__MINGW32__)
#include <filesystem>
namespace fs = std::filesystem;
#else
#include "ghc_filesystem.h"
namespace fs = ghc::filesystem;
#endif
