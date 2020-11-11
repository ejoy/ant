#pragma once

#include "context.h"
#include <RmlUi/Core/FileInterface.h>
#include <../Source/Core/FileInterfaceDefault.h>

class FileInterface : public Rml::FileInterfaceDefault {
public:
    FileInterface(const RmlContext*context) : mcontext(context){}
    virtual Rml::FileHandle Open(const Rml::String& path) override;

private:
    const RmlContext* mcontext;
};
