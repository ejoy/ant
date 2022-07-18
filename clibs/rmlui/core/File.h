#pragma once

#include <stdio.h>
#include <string>

namespace Rml {
    class File {
    public:
        File(const std::string& path);
        ~File();
        explicit operator bool() const;
        size_t Read(void* buffer, size_t size);
        size_t Length();
    private:
        FILE* handle;
    };
}
