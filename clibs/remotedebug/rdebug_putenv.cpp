#if defined(_MSC_VER)
#include "rdebug_delayload.h"
#include <Windows.h>
#include <stdint.h>

namespace remotedebug {
static uintptr_t rva_to_addr(HMODULE module, uintptr_t rva) {
    if (rva == 0) return 0;
    return (uintptr_t)module + rva;
}
static uintptr_t find_putenv() {
    HMODULE module = delayload::get_luadll();
    if (!module) {
        return 0;
    }
    PIMAGE_DOS_HEADER dos_header = (PIMAGE_DOS_HEADER)(module);
    PIMAGE_NT_HEADERS nt_headers = (PIMAGE_NT_HEADERS)((uintptr_t)(dos_header) + dos_header->e_lfanew);
    PIMAGE_IMPORT_DESCRIPTOR import = (PIMAGE_IMPORT_DESCRIPTOR)rva_to_addr(module, nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
    uint32_t size = nt_headers->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].Size;
    if (import == NULL || size < sizeof(IMAGE_IMPORT_DESCRIPTOR)) {
        return 0;
    }
    for (; import->FirstThunk; ++import) {
        PIMAGE_THUNK_DATA pitd = (PIMAGE_THUNK_DATA)rva_to_addr(module, import->OriginalFirstThunk);
        PIMAGE_THUNK_DATA pitd2 = (PIMAGE_THUNK_DATA)rva_to_addr(module, import->FirstThunk);
        for (;pitd->u1.Function; ++pitd, ++pitd2) {
            PIMAGE_IMPORT_BY_NAME pi_import_by_name = (PIMAGE_IMPORT_BY_NAME)(rva_to_addr(module, *(uintptr_t*)pitd));
            if (!IMAGE_SNAP_BY_ORDINAL(pitd->u1.Ordinal)) {
                const char* apiname = (const char*)pi_import_by_name->Name;
                if (0 == strcmp(apiname, "getenv") || 0 == strcmp(apiname, "_wgetenv")) {
                    HMODULE crt = GetModuleHandleA((const char*)rva_to_addr(module, import->Name));
                    if (crt) {
                        return (uintptr_t)GetProcAddress(crt, "_putenv");
                    }
                }
            }
        }
    }
    return 0;
}

void putenv(const char* envstr) {
    static auto lua_putenv = (int (__cdecl*) (const char*))find_putenv();
    if (lua_putenv) {
        lua_putenv(envstr);
    }
    else {
        ::_putenv(envstr);
    }
}

}
#endif
