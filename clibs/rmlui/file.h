#pragma once

#include "context.h"
#include <RmlUi/FileInterface.h>

class File : public Rml::FileInterface {
public:
    File(const RmlContext*context) : mcontext(context){}
    Rml::FileHandle Open(const std::string& path) override;
    void   Close(Rml::FileHandle file) override;
    size_t Read(void* buffer, size_t size, Rml::FileHandle file) override;
    bool   Seek(Rml::FileHandle file, long offset, int origin) override;
    size_t Tell(Rml::FileHandle file) override;
    std::string GetPath(const std::string& path) override;

private:
    const RmlContext* mcontext;
};
