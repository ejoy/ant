#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>

#define MAX_MSG_SIZE 0xffff

static int
read_size(const char * msg) {
	uint8_t byte1 = (uint8_t)msg[0];
	uint8_t byte2 = (uint8_t)msg[1];
	return byte1 + byte2 * 256;
}

static void
write_size(char *msg, int size) {
	msg[0] = (char)(size & 0xff);
	msg[1] = (char)( (size >> 8) & 0xff);
}

/*
static void
debug_stack(lua_State *L, int line) {
	int top = lua_gettop(L);
	printf("line %d: (%d) ",line, top);
	int i;
	for (i=1;i<=top;i++) {
		printf("%s ", lua_typename(L, lua_type(L, i)));
	}
	printf("\n");
}

#define T debug_stack(L, __LINE__);
*/

static void
clear_table(lua_State *L, int index, int from, int n) {
	int i;
	for (i=from;i<=n;i++) {
		lua_pushnil(L);
		lua_seti(L, index, i);
	}
}

static void
remove_input(lua_State *L, int from, int to, int n) {
	int i;
	for (i = from; i<=n; i++) {
		lua_geti(L, 1, i);
		lua_seti(L, 1, to);
		++to;
	}
	clear_table(L, 1, to, n);
}

static const char *
get_chunk(lua_State *L, int idx, int message_size, const char * msg, size_t sz, int n, char * buffer) {
	// stack top is the string (msg/sz)
	if (message_size <= sz) {
		if (message_size < sz) {
			lua_pushlstring(L, msg + message_size, sz - message_size);
			lua_seti(L, 1, 1);
		} else {
			// remove 1st string of input table
			remove_input(L, idx+1, 1, n);
		}
		lua_replace(L, 1);	// replace index 1 (input table) to prevent gc
		return msg;
	}
	int orig_sz = message_size;
	char * ptr = buffer + 2;
	memcpy(ptr, msg, sz);
	ptr+=sz;
	message_size -= sz;
	lua_pop(L, 1);
	int input_index;
	for (input_index = idx+1; input_index<=n; input_index++) {
		if (lua_geti(L, 1, input_index) != LUA_TSTRING)
			luaL_error(L, "Invalid input message at (%d) %s", input_index, lua_typename(L, lua_type(L, -1)));
		msg = lua_tolstring(L, -1, &sz);
		lua_pop(L, 1);
		if (message_size <= sz) {
			memcpy(ptr, msg, message_size);
			if (message_size < sz) {
				lua_pushlstring(L, msg + message_size, sz - message_size);
				lua_seti(L, 1, 1);
				remove_input(L, input_index+1, 2, n);
			} else {
				remove_input(L, input_index+1, 1, n);
			}
			return buffer + 2;
		}
		memcpy(ptr, msg, sz);
		ptr += sz;
		message_size -= sz;
	}
	sz = ptr - buffer - 2;
	write_size(buffer, orig_sz);
	lua_pushlstring(L, buffer, sz + 2);
	lua_seti(L, 1, 1);
	clear_table(L, 1, 2, n);
	return NULL;
}

static int
get_header(lua_State *L, int index) {
	for (;;) {
		int t = lua_geti(L, 1, index);
		if (t == LUA_TNIL) {
			return 0;
		}
		if (t != LUA_TSTRING) {
			return luaL_error(L, "Invalid message type : %s", lua_typename(L, lua_type(L, -1)));
		}
		size_t sz;
		lua_tolstring(L, -1, &sz);
		if (sz > 0) {
			return index;
		}
		lua_pop(L, 1);
		++index;
	}
}

static const char *
readchunk(lua_State *L, char *buffer, int *size) {
	luaL_checktype(L, 1, LUA_TTABLE);
	size_t n = lua_rawlen(L, 1);
	if (n == 0)	// no input
		return NULL;
	int index = get_header(L, 1);
	if (index == 0)
		return NULL;
	size_t sz;
	int message_size;
	const char * msg = lua_tolstring(L, -1, &sz);
	if (sz == 1) {
		message_size = (uint8_t)msg[0];
		lua_pop(L, 1);
		index = get_header(L, index+1);
		if (index == 0)
			return 0;
		msg = lua_tolstring(L, -1, &sz);
		message_size = message_size + 256 * (uint8_t)msg[0];
		msg += 1;
		sz -= 1;
	} else {
		message_size = read_size(msg);
		msg += 2;
		sz -= 2;
	}

	// little endian size
	const char * chunk = get_chunk(L, index, message_size, msg, sz, n, buffer);
	*size = message_size;
	return chunk;
}

/*
	params:
	table messages { strings, ... }
	
	return:
	string or none
 */
static int
lreadchunk(lua_State *L) {
	int size;
	char buffer[MAX_MSG_SIZE + 2];
	const char *chunk = readchunk(L, buffer, &size);
	if (chunk == NULL)
		return 0;
	lua_pushlstring(L, chunk, size);
	return 1;
}

/*
	params:
	table messages { strings, ... }
	table[opt] output {}
	
	return:
	table or none
 */

static int
extract_message(lua_State *L, const char *chunk, int size, int output_index) {
	int sz = read_size(chunk);
	if (sz + 2 > size) {
		return luaL_error(L, "Invalid message (%d/%d)", sz, size);
	}
	lua_pushlstring(L, chunk+2, sz);
	lua_seti(L, 2, output_index);

	return sz + 2;
}

static int
lreadmessage(lua_State *L) {
	int size;
	char buffer[MAX_MSG_SIZE+2];
	const char *chunk = readchunk(L, buffer, &size);
	if (chunk == NULL)
		return 0;

	if (lua_gettop(L) == 1) {
		// create output table
		lua_newtable(L);
	} else {
		luaL_checktype(L, 2, LUA_TTABLE);
		lua_settop(L, 2);
	}

	int index = 1;
	while (size > 0) {
		if (size == 1) {
			return luaL_error(L, "Invalid chunk");
		}

		int sz = extract_message(L, chunk, size, index);
		chunk += sz;
		size -= sz;
		index++;
	}
	clear_table(L, 2, index, lua_rawlen(L, 2));
	
	return 1;
}

static int
lpackmessage(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int n = lua_rawlen(L, 1);
	int size = 0;
	int i;
	char temp[MAX_MSG_SIZE + 2];
	char * ptr = temp + 2;
	for (i=0;i<n;i++) {
		if (lua_geti(L, 1, i+1) != LUA_TSTRING) {
			return luaL_error(L, "Invalid message type %s", lua_typename(L, lua_type(L, -1)));
		}
		size_t sz;
		const char *msg = lua_tolstring(L, -1, &sz);
		size += sz + 2;
		if (size > MAX_MSG_SIZE)
			return luaL_error(L, "Message is too long");
		write_size(ptr, sz);
		ptr += 2;
		memcpy(ptr, msg, sz);
		ptr += sz;
		lua_pop(L, 1);
	}
	write_size(temp, size);
	lua_pushlstring(L, temp, size + 2);
	return 1;
}

LUAMOD_API int
luaopen_protocol_core(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "readchunk", lreadchunk },
		{ "readmessage", lreadmessage },
		{ "packmessage", lpackmessage },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);
	return 1;
}