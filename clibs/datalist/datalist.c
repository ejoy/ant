#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define MAX_DEPTH 256
#define SHORT_STRING 1024

enum token_type {
	TOKEN_OPEN,	// {
	TOKEN_CLOSE,	// }
	TOKEN_MAP,	// = :
	TOKEN_LIST,	// ---
	TOKEN_STRING,
	TOKEN_ESCAPESTRING,
	TOKEN_ATOM,
	TOKEN_NEWLINE,	// space \t
	TOKEN_EOF,	// end of file
};

struct token {
	enum token_type type;
	ptrdiff_t from;
	ptrdiff_t to;
};

struct lex_state {
	const char *source;
	size_t sz;
	ptrdiff_t position;
	struct token c;
	struct token n;
	int newline;
	int aslist;
};

static const char *
skip_line_comment(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	while (ptr < endptr) {
		if (*ptr == '\r' || *ptr == '\n') {
			LS->position = ptr - LS->source;
			LS->newline = 1;
			return ptr;
		}
		++ptr;
	}
	return ptr;
}

static const char *
parse_ident(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	while (ptr < endptr) {
		switch (*ptr) {
		case '\r':
		case '\n':
			LS->newline = 1;
			return ptr+1;
		case '#':
			// empty line
			return ptr;
		case ' ':
		case '\t':
			break;
		default:
			LS->n.type = TOKEN_NEWLINE;
			LS->n.from = LS->position;
			LS->n.to = ptr - LS->source;
			LS->position = LS->n.to;
			return NULL;
		}
		++ptr;
	}
	return ptr;
}


static void
parse_atom(struct lex_state *LS) {
	static const char * separator = " \t\r\n,{}:=\"'";
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	LS->n.type = TOKEN_ATOM;
	LS->n.from = LS->position;
	while (ptr < endptr) {
		if (strchr(separator, *ptr)) {
			LS->n.to = ptr - LS->source;
			LS->position = LS->n.to;
			return;
		}
		++ptr;
	}
	LS->n.to = LS->sz;
	LS->position = LS->n.to;
}

static int
parse_string(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	char open_string = *ptr++;
	LS->n.type = TOKEN_STRING;
	LS->n.from = LS->position + 1;
	while (ptr < endptr) {
		char c = *ptr;
		if (c == open_string) {
			LS->n.to = ptr - LS->source;
			LS->position = ptr - LS->source + 1;
			return 1;
		}
		if (c == '\r' || c == '\n') {
			return 0;
		}
		if (c == '\\') {
			LS->n.type = TOKEN_ESCAPESTRING;
			++ptr;
		}
		++ptr;
	}
	return 0;
}

// 0 : invalid source
// 1 : ok
static int
next_token(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	while (ptr < endptr) {
		LS->position = ptr - LS->source;
		if (LS->newline) {
			// line head
			LS->newline = 0;
			const char * nextptr = parse_ident(LS);
			if (nextptr == NULL)
				return 1;
			// empty line
			ptr = nextptr;
			continue;
		}

		switch (*ptr) {
		case '#':
			// comment
			ptr = skip_line_comment(LS);
			continue;
		case '\r':
		case '\n':
			LS->newline = 1;
			++ptr;
			continue;
		case ' ':
		case '\t':
		case ',':
			break;
		case '{':
			LS->n.type = TOKEN_OPEN;
			LS->n.from = LS->position;
			LS->n.to = ++LS->position;
			return 1;
		case '}':
			LS->n.type = TOKEN_CLOSE;
			LS->n.from = LS->position;
			LS->n.to = ++LS->position;
			return 1;
		case '-':
			do ++ptr; while (ptr < endptr && *ptr == '-');
			if (ptr >= endptr || strchr(" \t\r\n", *ptr)) {
				LS->n.type = TOKEN_LIST;
				LS->n.from = LS->position;
				LS->n.to = ptr - LS->source;
				LS->position = LS->n.to;
			} else {
				// negative number
				parse_atom(LS);
			}
			return 1;
		case ':':
		case '=':
			LS->n.type = TOKEN_MAP;
			LS->n.from = LS->position;
			LS->n.to = ++LS->position;
			return 1;
		case '"':
		case '\'':
			return parse_string(LS);
		default:
			parse_atom(LS);
			return 1;
		}
		++ptr;
	}
	LS->n.type = TOKEN_EOF;
	LS->position = LS->sz;
	return 1;
}


static int
invalid(lua_State *L, struct lex_state *LS, const char * err) {
	ptrdiff_t index;
	int line = 1;
	ptrdiff_t position = LS->n.from;
	for (index = 0; index < position ; index ++) {
		if (LS->source[index] == '\n')
			++line;
	}
	return luaL_error(L, "Line %d : %s", line, err);
}

static inline int
read_token(lua_State *L, struct lex_state *LS) {
	if (LS->c.type == TOKEN_EOF) {
		invalid(L, LS, "End of data");
	}
	LS->c = LS->n;
	if (!next_token(LS))
		invalid(L, LS, "Invalid token");
//	printf("token %.*s\n", (int)(LS->c.to-LS->c.from), LS->source + LS->c.from);
	return LS->c.type;
}

static inline int
to_hex(char c) {
	if (c >= '0' && c <= '9')
		return c - '0';
	if (c >= 'a' && c <= 'f')
		return c - 'a' + 10;
	if (c >= 'A' && c <= 'F')
		return c - 'A' + 10;
	return -1;
}

static int
push_token_string(lua_State *L, const char *ptr, size_t sz) {
	char tmp[SHORT_STRING];
	char *buffer = tmp;
	assert(sz > 0);
	if (sz > SHORT_STRING) {
		buffer = lua_newuserdata(L, sz);
	}

	size_t i, n;
	for (n=i=0;i<sz;++i,++ptr,++n) {
		if (*ptr != '\\') {
			buffer[n] = *ptr;
		} else {
			++ptr;
			++i;
			assert(i < sz);
			char c = *ptr;
			if (c >= '0' && c <= '9') {
				// escape dec ascii
				int dec = c - '0';
				if (i+1 < sz) {
					int c2 = ptr[1];
					if (c2 >= '0' && c2 <= '9') {
						dec = dec * 10 + c2 - '0';
						++ptr;
						++i;
					}
				}
				if (i+1 < sz) {
					int c2 = ptr[1];
					if (c2 >= '0' && c2 <= '9') {
						int tmp = dec * 10 + c2 - '0';
						if (tmp <= 255) {
							dec = tmp;
							++ptr;
							++i;
						}
					}
				}
				buffer[n] = dec;
			} else {
				switch(*ptr) {
				case 'x':
				case 'X': {
					// escape hex ascii
					if (i+2 >= sz) {
						return 1;
					}
					++ptr;
					++i;
					int hex = to_hex(*ptr);
					if (hex < 0) {
						return 1;
					}
					++ptr;
					++i;
					int hex2 = to_hex(*ptr);
					if (hex2 > 0) {
						hex = hex * 16 + hex2;
					}
					buffer[n] = hex;
					break;
				}
				case 'n':
					buffer[n] = '\n';
					break;
				case 'r':
					buffer[n] = '\r';
					break;
				case 't':
					buffer[n] = '\t';
					break;
				case 'a':
					buffer[n] = '\a';
					break;
				case 'b':
					buffer[n] = '\b';
					break;
				case 'v':
					buffer[n] = '\v';
					break;
				case '\'':
					buffer[n] = '\'';
					break;
				case '"':
					buffer[n] = '"';
					break;
				default:
					return 1;
				}
			}
		}
	}
	lua_pushlstring(L, buffer, n);
	if (sz > SHORT_STRING) {
		lua_replace(L, -2);
	}
	return 0;
}

#define IS_KEYWORD(ptr, sz, str) (sizeof(str "") == sz+1 && (memcmp(ptr, str, sz) == 0))

static void
push_token(lua_State *L, struct lex_state *LS, struct token *t) {
	const char * ptr = LS->source + t->from;
	size_t sz = t->to - t->from;

	switch(t->type) {
	case TOKEN_STRING:
		lua_pushlstring(L, ptr, sz);
		return;
	case TOKEN_ESCAPESTRING:
		if (push_token_string(L, ptr, sz)) {
			invalid(L, LS, "Invalid quote string");
		}
		return;
	case TOKEN_ATOM:
		break;
	default:
		invalid(L, LS, "Invalid atom");
		return;
	}

	if (strchr("0123456789+-.", ptr[0])) {
		if (sz == 1) {
			char c = *ptr;
			if (c >= '0' && c <='9') {
				lua_pushinteger(L, c - '0');
			} else {
				lua_pushlstring(L, ptr, 1);
			}
			return;
		}

		if (sz >=3 && ptr[0] == '0' && (ptr[1] == 'x' || ptr[1] == 'X')) {
			// may be a hex integer
			lua_Integer v = 0;
			int hex = 1;
			size_t i;
			for (i=2;i<sz;i++) {
				char c = ptr[i];
				v = v * 16;
				if (c >= '0' && c <='9') {
					v += c - '0';
				} else if (c >= 'a' && c <= 'f') {
					v += c - 'a' + 10;
				} else if (c >= 'A' && c <= 'F') {
					v += c - 'A' + 10;
				} else {
					hex = 0;
					break;
				}
			}
			if (hex) {
				lua_pushinteger(L, v);
				return;
			}
		}

		// may be a number
		// lua string always has \0 at the end, so strto* is safe
		char *endptr = NULL;
		lua_Integer v = strtoull(ptr, &endptr, 10);
		if (endptr - ptr == sz) {
			lua_pushinteger(L, v);
			return;
		}

		endptr = NULL;
		lua_Number f = strtod(ptr, &endptr);
		if (endptr - ptr == sz) {
			lua_pushnumber(L, f);
			return;
		}
	}

	if (t->type == TOKEN_ATOM) {
		if (IS_KEYWORD(ptr, sz, "true") || IS_KEYWORD(ptr, sz, "yes") || IS_KEYWORD(ptr, sz, "on")) {
			lua_pushboolean(L, 1);
			return;
		} else if (IS_KEYWORD(ptr, sz, "false") || IS_KEYWORD(ptr, sz, "no") || IS_KEYWORD(ptr, sz, "off")) {
			lua_pushboolean(L, 0);
			return;
		} else if (IS_KEYWORD(ptr, sz, "nil")) {
			lua_pushnil(L);
			return;
		}
	}

	lua_pushlstring(L, ptr, sz);
}

static inline int
token_length(struct token *t) {
	return (t->to - t->from);
}

static inline int
token_symbol(struct lex_state *LS) {
	return LS->source[LS->c.from];
}

static inline void
push_key(lua_State *L, struct lex_state *LS) {
	lua_pushlstring(L, LS->source + LS->c.from, LS->c.to - LS->c.from);
}

static void
new_table(lua_State *L, int layer) {
	if (layer >= MAX_DEPTH)
		luaL_error(L, "too many layers");
	luaL_checkstack(L, 4, NULL);
	lua_newtable(L);
}

static void parse_bracket(lua_State *L, struct lex_state *LS, int layer);

static int
closed_bracket(lua_State *L, struct lex_state *LS) {
	for (;;) {
		switch (LS->c.type) {
		case TOKEN_CLOSE:
			read_token(L, LS);
			return 1;
		case TOKEN_NEWLINE:
			read_token(L, LS);
			break;
		default:
			return 0;
		}
	}
}

static void
parse_bracket_map(lua_State *L, struct lex_state *LS, int layer) {
	int i = 1;
	int aslist = LS->aslist;
	do {
		if (LS->c.type != TOKEN_ATOM) {
			invalid(L, LS, "Invalid key");
		}
		push_key(L, LS);
		if (read_token(L, LS) != TOKEN_MAP) {
			invalid(L, LS, "Need a : or =");
		}
		while (read_token(L, LS) == TOKEN_NEWLINE) ;
		switch (LS->c.type) {
		case TOKEN_OPEN:
			parse_bracket(L, LS, layer+1);
			break;
		default:
			push_token(L, LS, &LS->c);
			read_token(L, LS);
			break;
		}
		if (aslist) {
			lua_insert(L, -2);
			lua_seti(L, -3, i++);
			lua_seti(L, -2, i++);
		} else {
			lua_settable(L, -3);
		}
	} while (!closed_bracket(L, LS));
}

static void
parse_bracket_sequence(lua_State *L, struct lex_state *LS, int layer) {
	int n = 1;
	for (;;) {
		switch (LS->c.type) {
		case TOKEN_NEWLINE:
			read_token(L, LS);
			continue;	// skip ident
		case TOKEN_CLOSE:
			read_token(L, LS);	// consume }
			return;
		case TOKEN_OPEN:
			parse_bracket(L, LS, layer);
		default:
			push_token(L, LS, &LS->c);
			read_token(L, LS);
			break;
		}
		lua_seti(L, -2, n++);
	}
}

static void
parse_bracket(lua_State *L, struct lex_state *LS, int layer) {
	new_table(L, layer);
	switch (read_token(L, LS)) {
	case TOKEN_CLOSE:
		return;
	case TOKEN_ATOM:
		if (LS->n.type == TOKEN_MAP) {
			parse_bracket_map(L, LS, layer);
			return;
		}
		break;
	default:
		break;
	}
	parse_bracket_sequence(L, LS, layer);
}

static int
next_item(lua_State *L, struct lex_state *LS, int ident) {
	int t = LS->c.type;
	if (t == TOKEN_NEWLINE) {
		int next_ident = token_length(&LS->c);
		if (next_ident == ident) {
			if (LS->n.type == TOKEN_LIST)
				return 0;
			read_token(L, LS);
			return 1;
		} else if (next_ident > ident) {
			invalid(L, LS, "Invalid ident");
		} else {
			// end of sequence
			return 0;
		}
	} else if (t == TOKEN_EOF) {
		return 0;
	}
	return 1;
}

static void parse_section(lua_State *L, struct lex_state *LS, int layer);

static void
parse_section_map(lua_State *L, struct lex_state *LS, int ident, int layer) {
	int i = 1;
	int aslist = LS->aslist;
	do {
		if (LS->c.type != TOKEN_ATOM)
			invalid(L, LS, "Invalid key");
		push_key(L, LS);
		if (read_token(L, LS) != TOKEN_MAP) {
			invalid(L, LS, "Need a : or =");
		}
		switch (read_token(L, LS)) {
		case TOKEN_OPEN:
			parse_bracket(L, LS, layer+1);
			break;
		case TOKEN_NEWLINE: {
			int next_ident = token_length(&LS->c);
			if (next_ident <= ident) {
				invalid(L, LS, "Invalid new section ident");
			}
			new_table(L, layer+1);
			parse_section(L, LS, layer+1);
			break;
		}
		default:
			push_token(L, LS, &LS->c);
			read_token(L, LS);
			break;
		}
		if (aslist) {
			lua_insert(L, -2);
			lua_seti(L, -3, i++);
			lua_seti(L, -2, i++);
		} else {
			lua_settable(L, -3);
		}
	} while (next_item(L, LS, ident));
}

static void
parse_section_sequence(lua_State *L, struct lex_state *LS, int ident, int layer) {
	int n = 1;
	do {
		switch (LS->c.type) {
		case TOKEN_OPEN:
			parse_bracket(L, LS, layer+1);
			break;
		case TOKEN_LIST:
			// end of this section
			return;
		default:
			push_token(L, LS, &LS->c);
			read_token(L, LS);
			break;
		}
		lua_seti(L, -2, n++);
	} while(next_item(L, LS, ident));
}

static int
next_list(lua_State *L, struct lex_state *LS, int ident) {
	int t = LS->c.type;
	if (t == TOKEN_NEWLINE) {
		int next_ident = token_length(&LS->c);
		if (next_ident == ident) {
			switch (read_token(L, LS)) {
			case TOKEN_EOF:
				return 0;
			case TOKEN_LIST:
				// next list
				return 1;
			default:
				invalid(L, LS, "Invalid list");
				break;
			}
		} else if (next_ident < ident) {
			// end of sequence
			return 0;
		}
	}
	return 0;
}

static void
parse_section_list(lua_State *L, struct lex_state *LS, int ident, int layer) {
	int n = 1;
	do {
		switch (read_token(L, LS)) {
		case TOKEN_OPEN:
			parse_bracket(L, LS, layer+1);
			break;
		case TOKEN_NEWLINE: {
			int next_ident = token_length(&LS->c);
			if (next_ident >= ident) {
				new_table(L, layer + 1);
				if (LS->n.type != TOKEN_LIST || next_ident > ident) {
					// not an empty list
					parse_section(L, LS, layer + 1);
				}
			} else {
				// end of list
				return;
			}
			break;
		}
		case TOKEN_EOF:
			// empty list
			new_table(L, layer + 1);
			lua_seti(L, -2, n);
			return;
		default:
			push_token(L, LS, &LS->c);
			read_token(L, LS);
			break;
		}
		lua_seti(L, -2, n++);
	} while(next_list(L, LS, ident));
}

static void
parse_section(lua_State *L, struct lex_state *LS, int layer) {
	int ident = token_length(&LS->c);
	switch (read_token(L, LS)) {
	case TOKEN_ATOM:
		if (LS->n.type == TOKEN_MAP) {
			parse_section_map(L, LS, ident, layer);
			return;
		}
		break;
	case TOKEN_EOF:
		return;
	case TOKEN_STRING:
	case TOKEN_ESCAPESTRING:
	case TOKEN_OPEN:
		break;
	case TOKEN_LIST:
		parse_section_list(L, LS, ident, layer);
		return;
	default:
		invalid(L, LS, "Invalid section");
	}
	// a sequence
	parse_section_sequence(L, LS, ident, layer);
}

static void
init_lex(lua_State *L, int index, struct lex_state *LS) {
	LS->source = luaL_checklstring(L, 1, &LS->sz);
	LS->position = 0;
	LS->newline = 1;
	LS->aslist = 0;
	if (!next_token(LS))
		invalid(L, LS, "Invalid token");
}

static void
parse_all(lua_State *L, struct lex_state *LS) {
	int t = lua_type(L, 2);
	if (t == LUA_TTABLE || t == LUA_TUSERDATA) {
		lua_settop(L, 2);
	} else {
		new_table(L, 0);
	}
	int tt = read_token(L, LS);
	if (tt == TOKEN_EOF)
		return;
	assert(tt == TOKEN_NEWLINE);
	parse_section(L, LS, 0);
	if (LS->c.type != TOKEN_EOF) {
		invalid(L, LS, "not end");
	}
}

static int
lparse(lua_State *L) {
	struct lex_state LS;
	init_lex(L, 1, &LS);
	parse_all(L, &LS);
	return 1;
}

static int
lparse_list(lua_State *L) {
	struct lex_state LS;
	init_lex(L, 1, &LS);
	LS.aslist = 1;
	parse_all(L, &LS);
	return 1;
}

static int
ltoken(lua_State *L) {
	struct lex_state LS;
	init_lex(L, 1, &LS);

	lua_newtable(L);

	int n = 1;
	while(read_token(L, &LS) != TOKEN_EOF) {
		lua_pushlstring(L, LS.source + LS.c.from, LS.c.to - LS.c.from);
		lua_seti(L, -2, n++);
	}
	return 1;
}

LUAMOD_API int
luaopen_datalist(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "parse", lparse },
		{ "parse_list", lparse_list },
		{ "token", ltoken },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	return 1;
}