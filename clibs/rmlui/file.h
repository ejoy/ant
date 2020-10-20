#pragma once
#include <RmlUi/Core/FileInterface.h>
#include <../Source/Core/FileInterfaceDefault.h>

#include <unordered_map>

namespace Rml{
    class FileInterfaceDefault;
}

using FileDist = std::unordered_map<Rml::String, Rml::String>;
class FileInterface2 : public Rml::FileInterface{
public:
    FileInterface2(Rml::String &&rd, FileDist &&fd)
        : mRootDir(std::move(rd)), mFileDist(std::move(fd))
        {}

    virtual Rml::FileHandle Open(const Rml::String& path) override;
	virtual void Close(Rml::FileHandle file)override;

	virtual size_t Read(void* buffer, size_t size, Rml::FileHandle file)override;
	virtual bool Seek(Rml::FileHandle file, long offset, int origin)override;
	virtual size_t Tell(Rml::FileHandle file) override;

private:
    Rml::FileInterfaceDefault mFI;
    Rml::String mRootDir;
    FileDist    mFileDist;
};