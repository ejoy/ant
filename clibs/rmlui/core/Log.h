#pragma once

#include "Types.h"

namespace Rml {

class Log {
public:
	enum class Level {
		Always,
		Error,
		Warning,
		Info,
		Debug,
	};
	
	static void Message(Level level, const char* format, ...);
};

}
