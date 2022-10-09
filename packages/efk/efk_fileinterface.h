#pragma once

#include "../../clibs/fileinterface/fileinterface.h"
#include <Effekseer/Effekseer.h>

class EfkFileInterface : public Effekseer::FileInterface {
public:
    EfkFileInterface(struct file_interface *fi_) : fi(fi_) {}
    virtual ~EfkFileInterface() = default;
    virtual Effekseer::FileReaderRef OpenRead(const char16_t* path) override {
        char utf8_path[1024];
		Effekseer::ConvertUtf16ToUtf8(utf8_path, 1024, path);
        file_handle handle = file_open(fi, utf8_path, "rb");
        if (!handle) {
            return nullptr;
        }
        return Effekseer::MakeRefPtr<FileReader>(fi, handle);
    }

    virtual Effekseer::FileWriterRef OpenWrite(const char16_t *path) override {
        assert(false &&"invalid call");
        return nullptr;
    }

private:
    class FileReader : public Effekseer::FileReader{
    public:
        FileReader(struct file_interface* fi_, file_handle h_):fi(fi_), handle(h_){}
        virtual ~FileReader() {
            file_close(fi, handle);
        }
        virtual size_t Read(void* buffer, size_t size) override{
            return file_read(fi, handle, buffer, size);
        }
        virtual void Seek(int p) override{
            file_seek(fi, handle, p, SEEK_SET);
        }
        virtual int GetPosition() const override{
            return (int)file_tell(fi, handle);
        }
        virtual size_t GetLength() const override{
            const size_t ll = file_tell(fi, handle);
            file_seek(fi, handle, 0, SEEK_END);
            const size_t l = file_tell(fi, handle);
            file_seek(fi, handle, ll, SEEK_SET);
            return l;
        }
    private:
        struct file_interface* fi;
        file_handle handle;
    };
private:
    struct file_interface* fi;
};
