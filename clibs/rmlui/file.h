#pragma once

#include "context.h"
#include <RmlUi/Core/FileInterface.h>
#include <../Source/Core/FileInterfaceDefault.h>

class FileInterface2 : public Rml::FileInterfaceDefault {
public:
    FileInterface2(const rml_context *context) : mcontext(context){}
    virtual Rml::FileHandle Open(const Rml::String& path) override;

private:
    const rml_context* mcontext;
};
