#pragma once

#include "context.h"
#include <core/Interface.h>

class File : public Rml::FileInterface {
public:
    File() {}
    Rml::FileHandle Open(const std::string& path) override;
    void   Close(Rml::FileHandle file) override;
    size_t Read(void* buffer, size_t size, Rml::FileHandle file) override;
    size_t Length(Rml::FileHandle file) override;
    std::string GetPath(const std::string& path) override;
};
