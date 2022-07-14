#pragma once

#include <core/Interface.h>

class lua_plugin;

class File : public Rml::FileInterface {
public:
    File(lua_plugin& plugin);
    Rml::FileHandle Open(const std::string& path) override;
    void   Close(Rml::FileHandle file) override;
    size_t Read(void* buffer, size_t size, Rml::FileHandle file) override;
    size_t Length(Rml::FileHandle file) override;
    std::string GetPath(const std::string& path) override;
private:
    lua_plugin& plugin;
};
