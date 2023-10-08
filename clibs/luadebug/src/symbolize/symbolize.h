#pragma once

#include <optional>
#include <string>

namespace luadebug {
    struct symbol_info {
        std::optional<std::string> module_name;
        std::optional<std::string> function_name;
        std::optional<std::string> file_name;
        std::optional<std::string> line_number;
    };
    symbol_info symbolize(const void* ptr);
}
