#pragma once

#include "context.h"
#include <RmlUi/Core/FileInterface.h>
#include <../Source/Core/FileInterfaceDefault.h>

class File : public Rml::FileInterfaceDefault {
public:
    File(const rml_context *context) : mcontext(context){}
    virtual Rml::FileHandle Open(const Rml::String& path) override;

private:
    const rml_context* mcontext;
};
