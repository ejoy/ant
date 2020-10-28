#pragma once
#include "context.h"
#include <RmlUi/Core/FileInterface.h>
#include <../Source/Core/FileInterfaceDefault.h>

#include <unordered_map>

class FileInterface2 : public Rml::FileInterface{
public:
    FileInterface2(const rml_context *context) : mcontext(context){}

    virtual Rml::FileHandle Open(const Rml::String& path) override;
	virtual void Close(Rml::FileHandle file)override;

	virtual size_t Read(void* buffer, size_t size, Rml::FileHandle file)override;
	virtual bool Seek(Rml::FileHandle file, long offset, int origin)override;
	virtual size_t Tell(Rml::FileHandle file) override;

private:
    Rml::FileInterfaceDefault mFI;
    const rml_context* mcontext;
};