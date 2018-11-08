#include "winfile.h"
#include <stdio.h>
#include <windows.h>

int
main(int argc, char *argv[]) {

#define PATH (MAX_PATH*3)

	char tmp[PATH];
	wfile_personaldir(tmp, PATH);
	printf("home = %s %d\n", tmp, wfile_type(tmp));
	wfile_concat(tmp, PATH, "antclient");
	int client_type = wfile_type(tmp);
	printf("home test = %s %d\n", tmp, client_type);
	if (client_type == WFILE_FILE) {
		printf("%s is a file\n", tmp);
		return 1;
	}
	if (client_type == WFILE_NONE) {
		if (wfile_mkdir(tmp)) {
			printf("Mkdir %s\n", tmp);
		} else {
			printf("Can't create dir %s\n", tmp);
		}
	}
	wfile_concat(tmp, PATH, "test.txt");
	FILE *f = wfile_open(tmp, "wb");
	if (f == NULL) {
		printf("Can't write to %s\n", tmp);
		return 1;
	}
	fprintf(f, "Hello World");
	fclose(f);
	f = wfile_open(tmp, "rb");
	if (f == NULL) {
		printf("Can't read %s\n", tmp);
		return 1;
	}
	char buffer[128];
	char *s = fgets(buffer, sizeof(buffer), f);
	if (s) {
		printf("%s\n", s);
	}
	fclose(f);
	
	return 0;
}