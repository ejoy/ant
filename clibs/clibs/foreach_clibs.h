#pragma once

#include <functional>
#include <string>

#if defined(_MSC_VER)
#include <filesystem>
namespace fs = std::filesystem;
#else
#include <experimental/filesystem>
namespace fs = std::experimental::filesystem;
#endif

void foreach_clibs(const fs::path& dir, std::function<void(const fs::path&, const std::string&)> fn);
