#if defined(_MSC_VER)
	//  Microsoft 
#define MC_EXPORT __declspec(dllexport)
#define MC_IMPORT __declspec(dllimport)
#else
	//  do nothing and hope for the best?
#define MC_EXPORT
#define MC_IMPORT
//#pragma warning Unknown dynamic link import/export semantics.
#endif

#if defined(DISABLE_ASSERTS)
# define verify(expr) ((void)(expr))
#else
# define verify(expr) assert(expr)
#endif	