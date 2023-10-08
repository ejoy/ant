#pragma once

#if defined(_WIN32)

#    include <Windows.h>
#    include <intrin.h>

namespace luadebug::win32 {
    HMODULE get_luadll();
    void set_luadll(HMODULE handle);
    void set_luaapi(void* fn);
    void caller_is_luadll(void* callerAddress);
    void putenv(const char* envstr);
}

#endif
