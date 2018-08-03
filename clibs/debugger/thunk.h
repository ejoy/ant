#pragma once

#include <stdint.h>
#include <stddef.h>

struct shellcode {
	void*  data;
	size_t size;
	bool create(size_t size);
	void destory();
	bool write(void* buf);
};
shellcode thunk_create_hook(intptr_t dbg, intptr_t hook);
shellcode thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic);
void      thunk_destory(shellcode& shellcode);
