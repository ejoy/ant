#pragma once

#include <stdint.h>

namespace Rml {

class Log {
public:
	enum class Level : uint8_t {
		Always,
		Error,
		Warning,
		Info,
		Debug,
	};
	
	static void Message(Level level, const char* format, ...);
};

}
