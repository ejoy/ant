#include "config.h"
#include "winfile.h"
#include "luavm.h"
#include <stdlib.h>
#include <string.h>

static char *
read_file(const char *filename) {
	FILE *f = wfile_open(filename, "rb");
	if (f == NULL)
		return NULL;
	fseek(f, 0, SEEK_END);
	int sz = ftell(f);
	fseek(f, 0, SEEK_SET);
	char * buf = (char *)malloc(sz + 1);
	if (fread(buf, 1, sz, f) != sz) {
		free(buf);
		fclose(f);
		return NULL;
	}
	buf[sz] = 0;
	fclose(f);
	return buf;
}

#define CR "\n"
static const char * lua_loadconfig =
	"local log, config = ..." CR
	"_CONFIG = {}" CR
	"local f = assert(load(config, 'config', 't' , _CONFIG))" CR
	"f()" CR
	;

static const char * lua_get =
	"local c = _CONFIG" CR
	"return function(what)" CR
	"	return _CONFIG[what]" CR
	"end" CR
	;

struct call_context {
	struct luavm *V;
	int get_handle;
	const char *err;
};

static const char *
get_string(struct call_context *C, const char *what) {
	const char *result = NULL;
	C->err = luavm_call(C->V, C->get_handle, "sS", what, &result);
	return result;
}

static int
get_integer(struct call_context *C, const char *what) {
	int result = 0;
	C->err = luavm_call(C->V, C->get_handle, "sI", what, &result);
	return result;
}

const char *
antclient_loadconfig(const char *configpath, struct ant_client_config *result) {
	char * data = read_file(configpath);
	if (data == NULL)
		return 0;

	struct call_context C;
	C.V = luavm_new();

	C.err = luavm_init(C.V, lua_loadconfig, "s", data);

#define CHECK_ERR if (C.err) goto _err;

	CHECK_ERR;

	C.err = luavm_register(C.V, lua_get, "=get", &C.get_handle);
	CHECK_ERR;

	result->width = get_integer(&C, "width");
	CHECK_ERR;

	result->height = get_integer(&C, "height");
	CHECK_ERR;

	const char * tmp = get_string(&C, "title");
	CHECK_ERR;

	if (tmp == NULL) goto _err;
	strncpy(result->title, tmp, sizeof(result->title));
	result->title[sizeof(result->title)-1] = '\0';

	tmp = get_string(&C, "bootstrap");
	CHECK_ERR;
	if (tmp == NULL) goto _err;
	strncpy(result->bootstrap, tmp, sizeof(result->bootstrap));
	result->bootstrap[sizeof(result->bootstrap)-1] = '\0';

	luavm_close(C.V);
	return data;
_err:
	free(data);
	printf("Error: %s\n", C.err);
	luavm_close(C.V);
	return NULL;
}
