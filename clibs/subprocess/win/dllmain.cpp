#include <Windows.h>

BOOL APIENTRY DllMain(HMODULE module, DWORD reason, LPVOID pReserved) {
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(module);
    }
    return TRUE;
}
