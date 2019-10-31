/*
** $Id: lprefix.h $
** Definitions for Lua code that must come before any other header file
** See Copyright Notice in lua.h
*/

#ifndef lprefix_h
#define lprefix_h


/*
** Allows POSIX/XSI stuff
*/
#if !defined(LUA_USE_C89)	/* { */

#if !defined(_XOPEN_SOURCE)
#define _XOPEN_SOURCE           600
#elif _XOPEN_SOURCE == 0
#undef _XOPEN_SOURCE  /* use -D_XOPEN_SOURCE=0 to undefine it */
#endif

/*
** Allows manipulation of large files in gcc and some other compilers
*/
#if !defined(LUA_32BITS) && !defined(_FILE_OFFSET_BITS)
#define _LARGEFILE_SOURCE       1
#define _FILE_OFFSET_BITS       64
#endif

#endif				/* } */


/*
** Windows stuff
*/
#if defined(_WIN32) 	/* { */

#if !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS  /* avoid warnings about ISO C functions */
#endif

#include "utf8_prefix.h"

#endif			/* } */

#if !defined(NDEBUG)

#include <stdlib.h>
#include "lauxlib.h"

#define lua_assert(e) (void)(               \
        (!!(e)) ||                          \
        (                                   \
            fprintf(stderr, "(%s:%d) %s\n", \
                __FILE__,                   \
                (unsigned)(__LINE__),       \
                #e),                        \
            fflush(stderr),                 \
            abort(),                        \
            0                               \
        )                                   \
    )

#define luai_apicheck(l, e)                  \
    do {                                     \
        if (!(e)) {                          \
            fprintf(stderr, "(%s:%d) %s\n",  \
                __FILE__,                    \
                (unsigned)(__LINE__),        \
                #e);                         \
            fflush(stderr);                  \
            lua_checkstack((l), 6);          \
            luaL_traceback((l), (l), 0, 0);  \
            fprintf(stderr, "%s\n",          \
                lua_tostring((l), -1));      \
            fflush(stderr);                  \
            lua_pop((l), 1);                 \
            abort();                         \
        }                                    \
    } while(0)

#endif


#endif
