#include "pch.h"
#include "file.h"

Rml::FileHandle FileInterface2::Open(const Rml::String& path){
    auto p = path[0] == '/' ? path.c_str() + 1 : path;
    auto found = mcontext->file_dict.find(p);
    if (found != mcontext->file_dict.end()){
        return Rml::FileInterfaceDefault::Open(found->second);
    }
    return Rml::FileHandle(0);
}
