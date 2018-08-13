#include "vfs.h"
#include <stdio.h>

int
main() {
	struct vfs *V = vfs_init("firmware", ".");
	if (V == NULL) {
		printf("Init vfs failed.\n");
		return 1;
	}
	const char * source = vfs_load(V, ".firmware/bootstrap.lua");
	if (source) {
		printf("%s", source);
	} else {
		printf("Open .firmware/bootstrap.lua failed.\n");
	}
	vfs_exit(V);
	return 0;
}