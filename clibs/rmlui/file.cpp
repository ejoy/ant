#include "pch.h"
#include "file.h"

Rml::FileHandle File::Open(const Rml::String& path){
    auto found = mcontext->file_dict.find(path);
    if (found != mcontext->file_dict.end()){
        return Rml::FileInterfaceDefault::Open(found->second);
    }
    return Rml::FileHandle(0);
}
