#pragma once

#ifdef _DEBUG
#include <sstream>
#include <Windows.h>

static inline void
debug_print2(std::ostringstream& oss) {
	oss << std::endl;
	OutputDebugStringA(oss.str().c_str());
}

template<typename T, typename ...Args>
static void
debug_print2(std::ostringstream &oss, const T &t, Args... args){
	oss << t << "\t";
	debug_print2(oss, args...);
}

template<typename ...Args>
static void
debug_print(Args... args){
	std::ostringstream oss;
	debug_print2(oss, args...);
}
#endif //_DEBUG