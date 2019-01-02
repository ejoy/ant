#pragma once

#include <stdio.h>
#include "binding.h"
#if defined(_WIN32)
#include <Windows.h>
#endif

namespace ant::file {
    struct handle {
#if defined(_WIN32)
        typedef HANDLE value_type;
#else
        typedef int value_type;
#endif
        explicit handle() : value((value_type)-1) { }
        explicit handle(value_type v) : value(v) { }
        static const handle invalid() { return handle((value_type)-1); }
        operator bool() { return *this != invalid(); }
        operator value_type() { return value; }
        value_type* operator &() { return &value; }
        bool operator ==(handle other) { return value == other.value; }
        bool operator !=(handle other) { return value != other.value; }
    private:
        value_type value;
    };

    enum class mode {
        eRead,
        eWrite,
    };
    FILE*  open(handle h, mode m);
    handle get_handle(FILE* f);
    handle dup(FILE* f);
    handle lock(const lua::string_type& filename);
}
