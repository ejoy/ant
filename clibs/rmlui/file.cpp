#include "file.h"

#include <cassert>

Rml::FileHandle FileInterface2::Open(const Rml::String& path){
    auto p = path[0] == '/' ? path.c_str() + 1 : path;
    auto found = mcontext->file_dict.find(p);
    if (found != mcontext->file_dict.end()){
        return mFI.Open(found->second);
    }

    return Rml::FileHandle(0);
}

void FileInterface2::Close(Rml::FileHandle file){
    mFI.Close(file);
}

size_t FileInterface2::Read(void* buffer, size_t size, Rml::FileHandle file){
    return mFI.Read(buffer, size, file);
}

bool FileInterface2::Seek(Rml::FileHandle file, long offset, int origin){
    return mFI.Seek(file, offset, origin);
}

size_t FileInterface2::Tell(Rml::FileHandle file) {
    return mFI.Tell(file);
}