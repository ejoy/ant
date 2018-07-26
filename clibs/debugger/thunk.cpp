#include "thunk.h"

#if defined(_WIN32)
#include <Windows.h>
#else
#include <sys/mman.h>
#include <memory.h>
#endif

bool shellcode::create(size_t s) {
#if defined(_WIN32)
    data = VirtualAllocEx(GetCurrentProcess(), NULL, s, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
#else
    data = mmap(NULL, s, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
#endif
    if (!data) {
        size = 0;
        return false;
    }
    size = s;
    return true;
}

void shellcode::destory() {
    if (!data) return;
#if defined(_WIN32)
    VirtualFreeEx(GetCurrentProcess(), data, 0, MEM_RELEASE);
#else
    munmap(data, size);
#endif
    data = 0;
    size = 0;
}

bool shellcode::write(void* buf) {
#if defined(_WIN32)
    SIZE_T written = 0;
    BOOL ok = WriteProcessMemory(GetCurrentProcess(), data, buf, size, &written);
    if (!ok || written != size) {
        destory();
        return false;
    }
#else
    memcpy(data, buf, size);
#endif
    return true;
}

shellcode thunk_create_hook(intptr_t dbg, intptr_t hook)
{
    // int __cedel thunk_hook(lua_State* L, lua_Debug* ar)
    // {
    //     `hook`(`dbg`, L, ar);
    //     return `undefinition`;
    // }
    static unsigned char sc[] = {
#if defined(_M_X64)
        0x57,                                                       // push rdi
        0x50,                                                       // push rax
        0x48, 0x83, 0xec, 0x28,                                     // sub rsp, 40
        0x4c, 0x8b, 0xc2,                                           // mov r8, rdx
        0x48, 0x8b, 0xd1,                                           // mov rdx, rcx
        0x48, 0xb9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rcx, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rax, hook
        0xff, 0xd0,                                                 // call rax
        0x48, 0x83, 0xc4, 0x28,                                     // add rsp, 40
        0x58,                                                       // pop rax
        0x5f,                                                       // pop rdi
        0xc3,                                                       // ret
#else
        0xff, 0x74, 0x24, 0x08,       // push [esp+8]
        0xff, 0x74, 0x24, 0x08,       // push [esp+8]
        0x68, 0x00, 0x00, 0x00, 0x00, // push dbg
        0xe8, 0x00, 0x00, 0x00, 0x00, // call hook
        0x83, 0xc4, 0x0c,             // add esp, 12
        0xc3,                         // ret

#endif
    };
    shellcode shellcode;
    if (!shellcode.create(sizeof(sc))) {
        return shellcode;
    }
#if defined(_M_X64)
    memcpy(sc + 14, &dbg, sizeof(dbg));
    memcpy(sc + 24, &hook, sizeof(hook));
#else
    memcpy(sc + 9, &dbg, sizeof(dbg));
    hook = hook - ((intptr_t)shellcode.data + 18);
    memcpy(sc + 14, &hook, sizeof(hook));
#endif
    shellcode.write(&sc);
    return shellcode;
}

shellcode thunk_create_panic(intptr_t dbg, intptr_t panic)
{
    // int __cedel thunk_panic(lua_State* L)
    // {
    //    `panic`(`dbg`, L);
    //     return `undefinition`;
    // }
    static unsigned char sc[] = {
#if defined(_M_X64)
        0x57,                                                       // push rdi
        0x50,                                                       // push rax
        0x48, 0x83, 0xec, 0x28,                                     // sub rsp, 40
        0x48, 0x8b, 0xd1,                                           // mov rdx, rcx
        0x48, 0xb9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rcx, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rax, panic
        0xff, 0xd0,                                                 // call rax
        0x48, 0x83, 0xc4, 0x28,                                     // add rsp, 40
        0x58,                                                       // pop rax
        0x5f,                                                       // pop rdi
        0xc3,                                                       // ret
#else
        0xff, 0x74, 0x24, 0x04,       // push [esp+4]
        0x68, 0x00, 0x00, 0x00, 0x00, // push dbg
        0xe8, 0x00, 0x00, 0x00, 0x00, // call panic
        0x83, 0xc4, 0x08,             // add esp, 8
        0xc3,                         // ret

#endif
    };
    shellcode shellcode;
    if (!shellcode.create(sizeof(sc))) {
        return shellcode;
    }
#if defined(_M_X64)
    memcpy(sc + 11, &dbg, sizeof(dbg));
    memcpy(sc + 21, &panic, sizeof(panic));
#else
    memcpy(sc + 5, &dbg, sizeof(dbg));
    panic = panic - ((intptr_t)shellcode.data + 14);
    memcpy(sc + 10, &panic, sizeof(panic));
#endif
    shellcode.write(&sc);
    return shellcode;
}

shellcode thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic)
{
    if (!old_panic) {
        return thunk_create_panic(dbg, panic);
    }
    // int __cedel thunk_panic(lua_State* L)
    // {
    //    `panic`(`dbg`, L);
    //    `old_panic`(L);
    //     return `undefinition`;
    // }
    static unsigned char sc[] = {
#if defined(_M_X64)
        0x57,                                                       // push rdi
        0x50,                                                       // push rax
        0x51,                                                       // push rcx
        0x48, 0x83, 0xec, 0x28,                                     // sub rsp, 40
        0x48, 0x8b, 0xd1,                                           // mov rdx, rcx
        0x48, 0xb9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rcx, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rax, panic
        0xff, 0xd0,                                                 // call rax
        0x48, 0x83, 0xc4, 0x28,                                     // add rsp, 40
        0x59,                                                       // pop rcx
        0x48, 0x83, 0xec, 0x28,                                     // sub rsp, 40
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // mov rax, old_panic
        0xff, 0xd0,                                                 // call rax
        0x48, 0x83, 0xc4, 0x28,                                     // add rsp, 40
        0x58,                                                       // pop rax
        0x5f,                                                       // pop rdi
        0xc3,                                                       // ret
#else
        0xff, 0x74, 0x24, 0x04,       // push [esp+4]
        0x68, 0x00, 0x00, 0x00, 0x00, // push dbg
        0xe8, 0x00, 0x00, 0x00, 0x00, // call panic
        0x83, 0xc4, 0x08,             // add esp, 8
        0xff, 0x74, 0x24, 0x04,       // push [esp+4]
        0xe8, 0x00, 0x00, 0x00, 0x00, // call old_panic
        0x83, 0xc4, 0x04,             // add esp, 4
        0xc3,                         // ret

#endif
    };
    shellcode shellcode;
    if (!shellcode.create(sizeof(sc))) {
        return shellcode;
    }
#if defined(_M_X64)
    memcpy(sc + 12, &dbg, sizeof(dbg));
    memcpy(sc + 22, &panic, sizeof(panic));
    memcpy(sc + 43, &old_panic, sizeof(old_panic));
#else
    memcpy(sc + 5, &dbg, sizeof(dbg));
    panic = panic - ((intptr_t)shellcode.data + 14);
    memcpy(sc + 10, &panic, sizeof(panic));
    old_panic = old_panic - ((intptr_t)shellcode.data + 26);
    memcpy(sc + 22, &old_panic, sizeof(old_panic));
#endif
    shellcode.write(&sc);
    return shellcode;
}

void thunk_destory(shellcode shellcode)
{
    shellcode.destory();
}
