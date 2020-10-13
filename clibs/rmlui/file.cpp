#include "file.h"

#include <cassert>

Rml::FileHandle FileInterface2::Open(const Rml::String& path){
    auto found = mFileDist.find(path);
    if (found != mFileDist.end()){
        auto fh = mFI.Open(found->second);
        if (!fh){
            return mFI.Open(mRootDir + "/" + found->second);
        }
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