#pragma once

#include "Platform.h"
#include "Types.h"

namespace Rml {

class Log {
public:
	enum class Level {
		Always,
		Error,
		Assert,
		Warning,
		Info,
		Debug,
	};
	
	static void Message(Level level, const char* format, ...);
};

}
