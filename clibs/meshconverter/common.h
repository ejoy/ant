#if defined(_MSC_VER)
	//  Microsoft 
#define MC_EXPORT __declspec(dllexport)
#define MC_IMPORT __declspec(dllimport)
#elif defined(__GNUC__)
	//  GCC
//#define EXPORT	__attribute__(visibility("default"))
	// need force export, visibility("default") will follow static lib setting
#define MC_EXPORT	__attribute__((dllexport))
#define MC_IMPORT
#else
	//  do nothing and hope for the best?
#define MC_EXPORT
#define MC_IMPORT
#pragma warning Unknown dynamic link import/export semantics.
#endif