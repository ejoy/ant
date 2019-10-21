#include "thunk.h"
#include <memory>

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook)
{
	// int __cedel thunk_hook(lua_State* L, lua_Debug* ar)
	// {
	//     `hook`(`dbg`, L, ar);
	//     return `undefinition`;
	// }
	static unsigned char sc[] = {
		0xff, 0x74, 0x24, 0x08,       // push [esp+8]
		0xff, 0x74, 0x24, 0x08,       // push [esp+8]
		0x68, 0x00, 0x00, 0x00, 0x00, // push dbg
		0xe8, 0x00, 0x00, 0x00, 0x00, // call hook
		0x83, 0xc4, 0x0c,             // add esp, 12
		0xc3,                         // ret
	};
	std::unique_ptr<thunk> t(new thunk);
	if (!t->create(sizeof(sc))) {
		return 0;
	}
	memcpy(sc + 9, &dbg, sizeof(dbg));
	hook = hook - ((intptr_t)t->data + 18);
	memcpy(sc + 14, &hook, sizeof(hook));
	if (!t->write(&sc)) {
		return 0;
	}
	return t.release();
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic)
{
	// int __cedel thunk_panic(lua_State* L)
	// {
	//    `panic`(`dbg`, L);
	//     return `undefinition`;
	// }
	static unsigned char sc[] = {
		0xff, 0x74, 0x24, 0x04,       // push [esp+4]
		0x68, 0x00, 0x00, 0x00, 0x00, // push dbg
		0xe8, 0x00, 0x00, 0x00, 0x00, // call panic
		0x83, 0xc4, 0x08,             // add esp, 8
		0xc3,                         // ret
	};
	std::unique_ptr<thunk> t(new thunk);
	if (!t->create(sizeof(sc))) {
		return 0;
	}
	memcpy(sc + 5, &dbg, sizeof(dbg));
	panic = panic - ((intptr_t)t->data + 14);
	memcpy(sc + 10, &panic, sizeof(panic));
	if (!t->write(&sc)) {
		return 0;
	}
	return t.release();
}
