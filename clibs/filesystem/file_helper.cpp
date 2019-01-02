#include "file_helper.h"
#include <assert.h>
#include <fcntl.h>
#if defined(_WIN32)
#include <io.h>
#else
#include <sys/stat.h>
#include <sys/file.h>
#include <unistd.h>
#endif

namespace ant::file {

#if defined(_WIN32)
    FILE* open(handle h, mode m) {
        switch (m) {
        case mode::eRead: {
            int fn = _open_osfhandle((intptr_t)(HANDLE)h, _O_RDONLY | _O_BINARY);
            if (fn == -1) {
                return 0;
            }
            return _fdopen(fn, "rb");
        }
        case mode::eWrite: {
            int fn = _open_osfhandle((intptr_t)(HANDLE)h, _O_WRONLY | _O_BINARY);
            if (fn == -1) {
                return 0;
            }
            return _fdopen(fn, "wb");
        }
        default:
            assert(false);
            return 0;
        }
    }

    handle get_handle(FILE* f) {
        int n = _fileno(f);
        if (n < 0) {
            return handle::invalid();
        }
        return handle((HANDLE)_get_osfhandle(n));
    }

    handle dup(FILE* f) {
        handle h = get_handle(f);
        if (!h) {
            return handle::invalid();
        }
        handle newh;
        if (!::DuplicateHandle(::GetCurrentProcess(), h, ::GetCurrentProcess(), &newh, 0, FALSE, DUPLICATE_SAME_ACCESS)) {
            return handle::invalid();
        }
        return newh;
    }

    handle lock(const lua::string_type& filename) {
        return handle(CreateFileW(filename.c_str(),
            GENERIC_WRITE,
            0, NULL,
            CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL | FILE_FLAG_DELETE_ON_CLOSE,
            NULL
        ));
    }
#else
    FILE* open(handle h, mode m) {
        switch (m) {
        case mode::eRead:
            return fdopen(h, "rb");
        case mode::eWrite:
            return fdopen(h, "wb");
        default:
            assert(false);
            return 0;
        }
    }

    handle get_handle(FILE* f) {
        return handle(fileno(f));
    }

    handle dup(FILE* f) {
        return handle(::dup(get_handle(f)));
    }

    handle lock(const lua::string_type& filename) {
#if defined(__APPLE__) 
        int fd = ::open(filename.c_str(), O_WRONLY | O_CREAT | O_TRUNC | O_EXLOCK | O_NONBLOCK, 0644);
        return handle(fd);
#else
        int fd = ::open(filename.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd == -1) {
            return handle::invalid();
        }
        if (::flock(fd, LOCK_EX | LOCK_NB) == -1) {
            close(fd);
            return handle::invalid();
        }
        return handle(fd);
#endif
    }
#endif
}
