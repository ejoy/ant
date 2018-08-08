#include "luavm.h"
#include <stdio.h>

static void
err(struct luavm *V) {
	printf("%s\n", luavm_lasterror(V));
}

int
main() {
	struct luavm *V = luavm_new();
	if (luavm_init(V, "_ERR = ... ", NULL)) {
		err(V);
	}
	int handle = luavm_register(V, "return function(...) print (...) ; error 'ERR' end", "=print");
	if (handle == 0) {
		err(V);
	}
	int printerr = luavm_register(V, "local err = _ERR; return function() for i,err in ipairs(err) do print(i, err); err[i] = nil end end", "=printerr");
	if (printerr == 0) {
		err(V);
	}
	if (luavm_call(V, handle, "snib", "Hello", 1.0,2,0)) {
		luavm_call(V, printerr, NULL);
	}
	luavm_close(V);
	return 0;
}
