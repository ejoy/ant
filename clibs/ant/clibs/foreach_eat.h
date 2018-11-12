#pragma once

#include <functional>
#include <string>

void foreach_eat(const wchar_t* dll, std::function<void(const std::string&)> fn);
