#pragma once

#include <functional>
#include <string>

#if defined(_MSC_VER)
#include <filesystem>
#else
#include <experimental/filesystem>
#endif

namespace fs = std::experimental::filesystem;

void foreach_clibs(const fs::path& dir, std::function<void(const fs::path&, const std::string&)> fn);
