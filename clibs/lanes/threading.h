/*
* THREADING.H
*/
#ifndef __threading_h__
#define __threading_h__ 1

/* Platform detection
 * win32-pthread:
 * define HAVE_WIN32_PTHREAD and PTW32_INCLUDE_WINDOWS_H in your project configuration when building for win32-pthread.
 * link against pthreadVC2.lib, and of course have pthreadVC2.dll somewhere in your path.
 */
#ifdef _WIN32_WCE
  #define PLATFORM_POCKETPC
#elif defined(_XBOX)
  #define PLATFORM_XBOX
#elif (defined _WIN32)
  #define PLATFORM_WIN32
#elif (defined __linux__)
  #define PLATFORM_LINUX
#elif (defined __APPLE__) && (defined __MACH__)
  #define PLATFORM_OSX
#elif (defined __NetBSD__) || (defined __FreeBSD__) || (defined BSD)
  #define PLATFORM_BSD
#elif (defined __QNX__)
  #define PLATFORM_QNX
#elif (defined __CYGWIN__)
  #define PLATFORM_CYGWIN
#else
  #error "Unknown platform!"
#endif

typedef int bool_t;
#ifndef FALSE
# define FALSE 0
# define TRUE 1
#endif

typedef unsigned int uint_t;

#include <time.h>

/* Note: ERROR is a defined entity on Win32
  PENDING: The Lua VM hasn't done anything yet.
  RUNNING, WAITING: Thread is inside the Lua VM. If the thread is forcefully stopped, we can't lua_close() the Lua State.
  DONE, ERROR_ST, CANCELLED: Thread execution is outside the Lua VM. It can be lua_close()d.
*/
enum e_status { PENDING, RUNNING, WAITING, DONE, ERROR_ST, CANCELLED };

#define THREADAPI_WINDOWS 1
#define THREADAPI_PTHREAD 2

#if( defined( PLATFORM_XBOX) || defined( PLATFORM_WIN32) || defined( PLATFORM_POCKETPC)) && !defined( HAVE_WIN32_PTHREAD)
#define THREADAPI THREADAPI_WINDOWS
#else // (defined PLATFORM_WIN32) || (defined PLATFORM_POCKETPC)
#define THREADAPI THREADAPI_PTHREAD
#endif // (defined PLATFORM_WIN32) || (defined PLATFORM_POCKETPC)

/*---=== Locks & Signals ===---
*/

#if THREADAPI == THREADAPI_WINDOWS
  #if defined( PLATFORM_XBOX)
    #include <xtl.h>
  #else // !PLATFORM_XBOX
    #define WIN32_LEAN_AND_MEAN
    // CONDITION_VARIABLE needs version 0x0600+
    // _WIN32_WINNT value is already defined by MinGW, but not by MSVC
    #ifndef _WIN32_WINNT
    #define _WIN32_WINNT 0x0600
    #endif // _WIN32_WINNT
    #include <windows.h>
  #endif // !PLATFORM_XBOX
  #include <process.h>

/*
#define XSTR(x) STR(x)
#define STR(x) #x
#pragma message( "The value of _WIN32_WINNT: " XSTR(_WIN32_WINNT))
*/

  // MSDN: http://msdn2.microsoft.com/en-us/library/ms684254.aspx
  //
  // CRITICAL_SECTION can be used for simple code protection. Mutexes are
  // needed for use with the SIGNAL system.
  //

	#if _WIN32_WINNT < 0x0600 // CONDITION_VARIABLE aren't available, use a signal

	typedef struct
	{
		CRITICAL_SECTION    signalCS;
		CRITICAL_SECTION    countCS;
		HANDLE      waitEvent;
		HANDLE      waitDoneEvent;
		LONG        waitersCount;
	} SIGNAL_T;


	#define MUTEX_T HANDLE
	void MUTEX_INIT( MUTEX_T* ref);
	void MUTEX_FREE( MUTEX_T* ref);
	void MUTEX_LOCK( MUTEX_T* ref);
	void MUTEX_UNLOCK( MUTEX_T* ref);

	#else // CONDITION_VARIABLE are available, use them

	#define SIGNAL_T CONDITION_VARIABLE
	#define MUTEX_T CRITICAL_SECTION
	#define MUTEX_INIT( ref) InitializeCriticalSection( ref)
	#define MUTEX_FREE( ref) DeleteCriticalSection( ref)
	#define MUTEX_LOCK( ref) EnterCriticalSection( ref)
	#define MUTEX_UNLOCK( ref) LeaveCriticalSection( ref)

	#endif // CONDITION_VARIABLE are available

  #define MUTEX_RECURSIVE_INIT(ref)  MUTEX_INIT(ref)  /* always recursive in Win32 */

  typedef unsigned int THREAD_RETURN_T;

  #define YIELD() Sleep(0)
	#define THREAD_CALLCONV __stdcall
#else // THREADAPI == THREADAPI_PTHREAD
  // PThread (Linux, OS X, ...)

  // looks like some MinGW installations don't support PTW32_INCLUDE_WINDOWS_H, so let's include it ourselves, just in case
  #if defined(PLATFORM_WIN32)
  #include <windows.h>
  #endif // PLATFORM_WIN32
  #include <pthread.h>

  #ifdef PLATFORM_LINUX
  # define _MUTEX_RECURSIVE PTHREAD_MUTEX_RECURSIVE_NP
  #else
    /* OS X, ... */
  # define _MUTEX_RECURSIVE PTHREAD_MUTEX_RECURSIVE
  #endif

  #define MUTEX_T            pthread_mutex_t
  #define MUTEX_INIT(ref)    pthread_mutex_init(ref,NULL)
  #define MUTEX_RECURSIVE_INIT(ref) \
      { pthread_mutexattr_t a; pthread_mutexattr_init( &a ); \
        pthread_mutexattr_settype( &a, _MUTEX_RECURSIVE ); \
        pthread_mutex_init(ref,&a); pthread_mutexattr_destroy( &a ); \
      }
  #define MUTEX_FREE(ref)    pthread_mutex_destroy(ref)
  #define MUTEX_LOCK(ref)    pthread_mutex_lock(ref)
  #define MUTEX_UNLOCK(ref)  pthread_mutex_unlock(ref)

  typedef void * THREAD_RETURN_T;

  typedef pthread_cond_t SIGNAL_T;

  void SIGNAL_ONE( SIGNAL_T *ref );

  // Yield is non-portable:
  //
  //    OS X 10.4.8/9 has pthread_yield_np()
  //    Linux 2.4   has pthread_yield() if _GNU_SOURCE is #defined
  //    FreeBSD 6.2 has pthread_yield()
  //    ...
  //
  #if defined( PLATFORM_OSX)
    #define YIELD() pthread_yield_np()
  #elif defined( PLATFORM_WIN32) || defined( PLATFORM_POCKETPC) // no PTHREAD for PLATFORM_XBOX
    // for some reason win32-pthread doesn't have pthread_yield(), but sched_yield()
    #define YIELD() sched_yield()
  #else
    #define YIELD() pthread_yield()
  #endif
	#define THREAD_CALLCONV
#endif //THREADAPI == THREADAPI_PTHREAD

void SIGNAL_INIT( SIGNAL_T *ref );
void SIGNAL_FREE( SIGNAL_T *ref );
void SIGNAL_ALL( SIGNAL_T *ref );

/*
* 'time_d': <0.0 for no timeout
*           0.0 for instant check
*           >0.0 absolute timeout in secs + ms
*/
typedef double time_d;
time_d now_secs(void);

time_d SIGNAL_TIMEOUT_PREPARE( double rel_secs );

bool_t SIGNAL_WAIT( SIGNAL_T *ref, MUTEX_T *mu, time_d timeout );


/*---=== Threading ===---
*/

#if THREADAPI == THREADAPI_WINDOWS

	typedef HANDLE THREAD_T;
#	define THREAD_ISNULL( _h) (_h == 0)
	void THREAD_CREATE( THREAD_T* ref, THREAD_RETURN_T (__stdcall *func)( void*), void* data, int prio /* -3..+3 */);

#	define THREAD_PRIO_MIN (-3)
#	define THREAD_PRIO_MAX (+3)

#	define THREAD_CLEANUP_PUSH( cb_, val_)
#	define THREAD_CLEANUP_POP( execute_)

#else // THREADAPI == THREADAPI_PTHREAD

	/* Platforms that have a timed 'pthread_join()' can get away with a simpler
	 * implementation. Others will use a condition variable.
	 */
#	if defined __WINPTHREADS_VERSION
//#		define USE_PTHREAD_TIMEDJOIN
#	endif // __WINPTHREADS_VERSION

# ifdef USE_PTHREAD_TIMEDJOIN
#  ifdef PLATFORM_OSX
#   error "No 'pthread_timedjoin()' on this system"
#  else
    /* Linux, ... */
#   define PTHREAD_TIMEDJOIN pthread_timedjoin_np
#  endif
# endif

	typedef pthread_t THREAD_T;
#	define THREAD_ISNULL( _h) 0 // pthread_t may be a structure: never 'null' by itself

	void THREAD_CREATE( THREAD_T* ref, THREAD_RETURN_T (*func)( void*), void* data, int prio /* -3..+3 */);

#	if defined(PLATFORM_LINUX)
		extern volatile bool_t sudo;
#		ifdef LINUX_SCHED_RR
#			define THREAD_PRIO_MIN (sudo ? -3 : 0)
#		else
#			define THREAD_PRIO_MIN (0)
#		endif
#		define THREAD_PRIO_MAX (sudo ? +3 : 0)
#	else
#		define THREAD_PRIO_MIN (-3)
#		define THREAD_PRIO_MAX (+3)
#	endif

#	if THREADWAIT_METHOD == THREADWAIT_CONDVAR
#		define THREAD_CLEANUP_PUSH( cb_, val_) pthread_cleanup_push( cb_, val_)
#		define THREAD_CLEANUP_POP( execute_) pthread_cleanup_pop( execute_)
#	else
#		define THREAD_CLEANUP_PUSH( cb_, val_) {
#		define THREAD_CLEANUP_POP( execute_) }
#	endif // THREADWAIT_METHOD == THREADWAIT_CONDVAR
#endif // THREADAPI == THREADAPI_WINDOWS

/*
* Win32 and PTHREAD_TIMEDJOIN allow waiting for a thread with a timeout.
* Posix without PTHREAD_TIMEDJOIN needs to use a condition variable approach.
*/
#define THREADWAIT_TIMEOUT 1
#define THREADWAIT_CONDVAR 2

#if THREADAPI == THREADAPI_WINDOWS || (defined PTHREAD_TIMEDJOIN)
#define THREADWAIT_METHOD THREADWAIT_TIMEOUT
#else // THREADAPI == THREADAPI_WINDOWS || (defined PTHREAD_TIMEDJOIN)
#define THREADWAIT_METHOD THREADWAIT_CONDVAR
#endif // THREADAPI == THREADAPI_WINDOWS || (defined PTHREAD_TIMEDJOIN)


#if THREADWAIT_METHOD == THREADWAIT_TIMEOUT
bool_t THREAD_WAIT_IMPL( THREAD_T *ref, double secs);
#define THREAD_WAIT( a, b, c, d, e) THREAD_WAIT_IMPL( a, b)
#else // THREADWAIT_METHOD == THREADWAIT_CONDVAR
bool_t THREAD_WAIT_IMPL( THREAD_T *ref, double secs, SIGNAL_T *signal_ref, MUTEX_T *mu_ref, volatile enum e_status *st_ref);
#define THREAD_WAIT THREAD_WAIT_IMPL
#endif // // THREADWAIT_METHOD == THREADWAIT_CONDVAR

void THREAD_KILL( THREAD_T* ref);
void THREAD_SETNAME( char const* _name);
void THREAD_MAKE_ASYNCH_CANCELLABLE();
void THREAD_SET_PRIORITY( int prio);

#endif // __threading_h__
