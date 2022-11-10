#define RLUA_REPLACE
#include "rlua.h"
#include "rdebug_cmodule.h"
#include <binding/lua_socket.cpp>
#include <binding/lua_thread.cpp>

#if defined(_WIN32)
#include <binding/lua_unicode.cpp>
#include <bee/thread/simplethread_win.cpp>
#else
#include <bee/thread/simplethread_posix.cpp>
#endif

#include <bee/utility/path_helper.cpp>
#include <bee/utility/file_handle.cpp>

#if defined(_WIN32)
#include <bee/utility/file_handle_win.cpp>
#else
#include <bee/utility/file_handle_posix.cpp>
#endif

#if defined(__APPLE__)
#include <bee/utility/file_handle_osx.cpp>
#elif defined(__linux__)
#include <bee/utility/file_handle_linux.cpp>
#elif defined(__NetBSD__) || defined(__FreeBSD__) || defined(__OpenBSD__)
#include <bee/utility/file_handle_bsd.cpp>
#endif

#if !defined(LUAI_UACINT)
#   if defined(_MSC_VER)
#       define LUAI_UACINT __int64
#   else
#       define LUAI_UACINT long long
#   endif
#endif

#if !defined(LUA_INTEGER_FMT)
#   if defined(_MSC_VER)
#       define LUA_INTEGER_FMT "%I64d"
#   else
#       define LUA_INTEGER_FMT "%lld"
#   endif
#endif

#include <binding/lua_filesystem.cpp>
