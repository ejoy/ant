#ifndef __EFFEKSEER_PROFILER_H__
#define __EFFEKSEER_PROFILER_H__

#ifdef BUILD_WITH_EASY_PROFILER

#define EASY_PROFILER_STATIC
#include <easy/profiler.h>

#define PROFILER_BLOCK(name, ...) EASY_BLOCK(name, __VA_ARGS__)
#define PROFILER_THREAD(name) EASY_THREAD(name)

#else

#define PROFILER_BLOCK(name, ...)
#define PROFILER_THREAD(name)

#endif

#endif