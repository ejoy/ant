#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <string.h>
#include <assert.h>

#define MAX_DEPTH 256
#define SHORT_STRING 1024

enum token_type {
	TOKEN_BRACKET,	// {} []
	TOKEN_SYMBOL,	// = :
	TOKEN_LAYER,	// ## **
	TOKEN_STRING,
	TOKEN_ESCAPESTRING,
	TOKEN_ATOM,
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
	struct token t;
};

static const char *
skip_line_comment(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	while (ptr < endptr) {
		if (*ptr == '\r' || *ptr == '\n') {
			LS->position = ptr - LS->source;
			return ptr;
		}
		++ptr;
	}
	return ptr;
}

static void
parse_atom(struct lex_state *LS) {
	static const char * separator = " \t\r\n,{}[]:=\"'";
	static const char * dsep = "-#*";
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	LS->t.type = TOKEN_ATOM;
	LS->t.from = LS->position;
	while (ptr < endptr) {
		if (strchr(separator, *ptr) ||
			(ptr[0] == ptr[1] && strchr(dsep, *ptr))) {
			LS->t.to = ptr - LS->source;
			LS->position = LS->t.to;
			return;
		}
		++ptr;
	}
	LS->t.to = LS->sz;
	LS->position = LS->t.to;
}

static void
parse_layer(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	char c = *ptr++;
	while (ptr < endptr) {
		if (*ptr != c) {
			LS->t.from = LS->position;
			LS->t.to = ptr - LS->source;
			if (LS->t.to - LS->t.from == 1) {
				// Only one # or * is not a layer symbol.
				parse_atom(LS);
				break;
			} else {
				LS->t.type = TOKEN_LAYER;
			}
			LS->position = LS->t.to;
			break;
		}
		++ptr;
	}
}

static int
parse_string(struct lex_state *LS) {
	const char * ptr = LS->source + LS->position;
	const char * endptr = LS->source + LS->sz;
	char open_string = *ptr++;
	LS->t.type = TOKEN_STRING;
	LS->t.from = LS->position + 1;
	while (ptr < endptr) {
		char c = *ptr;
		if (c == open_string) {
			LS->t.to = ptr - LS->source;
			LS->position = ptr - LS->source + 1;
			return 1;
		}
		if (c == '\r' || c == '\n') {
			return 0;
		}
		if (c == '\\') {
			LS->t.type = TOKEN_ESCAPESTRING;
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
		// source string has \0 at the end, ptr[1] is safe to access.
		if (ptr[0] == '-' && ptr[1] == '-') {
			// comment
			ptr = skip_line_comment(LS);
			continue;
		}
		switch (*ptr) {
		case ' ':
		case '\t':
		case '\r':
		case '\n':
		case ',':
			break;
		case '{':
		case '}':
		case '[':
		case ']':
			LS->t.type = TOKEN_BRACKET;
			LS->t.from = LS->position;
			LS->t.to = ++LS->position;
			return 1;
		case ':':
		case '=':
			LS->t.type = TOKEN_SYMBOL;
			LS->t.from = LS->position;
			LS->t.to = ++LS->position;
			return 1;
		case '#':
		case '*':
			parse_layer(LS);
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
	LS->t.type = TOKEN_EOF;
	LS->position = LS->sz;
	return 1;
}

static int
invalid(lua_State *L, struct lex_state *LS, const char * err) {
	ptrdiff_t index;
	int line = 1;
	ptrdiff_t position = LS->t.from;
	for (index = 0; index < position ; index ++) {
		if (LS->source[index] == '\n')
			++line;
	}
	return luaL_error(L, "Line %d : %s", line, err);
}

static inline int
read_token(lua_State *L, struct lex_state *LS) {
	if (!next_token(LS))
		invalid(L, LS, "Invalid token");
//	printf("token %.*s\n", (int)(LS->t.to-LS->t.from), LS->source + LS->t.from);
	return LS->t.type;
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
layer_depth(struct lex_state *LS) {
	return (LS->t.to - LS->t.from) - 1;
}

static inline int
token_symbol(struct lex_state *LS) {
	return LS->source[LS->t.from];
}

static inline void
push_key(lua_State *L, struct lex_state *LS, struct token *t) {
	lua_pushlstring(L, LS->source + t->from, t->to - t->from);
}

static inline void
pair_seti(lua_State *L, int n) {
	// table k v
	lua_seti(L, -3, n * 2 );
	lua_seti(L, -2, n * 2 - 1);
}

static void
new_table(lua_State *L, int layer) {
	if (layer >= MAX_DEPTH)
		luaL_error(L, "too many layers");
	luaL_checkstack(L, 4, NULL);
	lua_newtable(L);
}

static void push_value(lua_State *L, struct lex_state *LS, int layer);

static inline int
is_closed(struct lex_state *LS) {
	switch (LS->t.type) {
		case TOKEN_EOF :
		case TOKEN_LAYER:
			return 1;
		case TOKEN_BRACKET:
			switch (token_symbol(LS)) {
			case '}':
			case ']':
				return 1;
			}
			break;
		default:
			break;
	}
	return 0;
}

static void
parse_seq(lua_State *L, struct lex_state *LS, int layer, int n) {
	for (;;) {
		read_token(L, LS);
		if (is_closed(LS))
			return;
		push_value(L, LS, layer);
		lua_seti(L, -2, n);
		++n;
	}
}

static int
read_first_kv(lua_State *L, struct lex_state *LS, int layer) {
	struct token key = LS->t;
	// It may be a key
	if (read_token(L, LS) != TOKEN_SYMBOL) {
		// It's a seq
		push_token(L, LS, &key);
		lua_seti(L, -2, 1);
		if (is_closed(LS))
			return 0;
		push_value(L, LS, layer);
		lua_seti(L, -2, 2);
		parse_seq(L, LS, layer, 3);
		return 0;
	}
	push_key(L, LS, &key);
	read_token(L, LS);
	push_value(L, LS, layer);
	return 1;
}

static int
try_kv(lua_State *L, struct lex_state *LS, int layer) {
	switch (read_token(L, LS)) {
	case TOKEN_EOF:
	case TOKEN_LAYER:
	case TOKEN_SYMBOL:
		invalid(L, LS, "Invalid token in a list");
		return 0;
	case TOKEN_ATOM:
		return read_first_kv(L, LS, layer);
	case TOKEN_BRACKET:
		switch (token_symbol(LS)) {
			case '}':
			case ']':
				// It is a empty list
				return 0;
			default:
				break;
		}
		// go through
	default:
		push_value(L, LS, layer);
		lua_seti(L, -2, 1);
		parse_seq(L, LS, layer, 2);
		return 0;
	}
}

static int
parse_kv(lua_State *L, struct lex_state *LS, int layer) {
	switch (read_token(L, LS)) {
	case TOKEN_EOF:
		invalid(L, LS, "Need close bracket");
		return 0;
	case TOKEN_BRACKET:
		return 0;
	case TOKEN_ATOM: {
		push_key(L, LS, &LS->t);
		if (read_token(L, LS) != TOKEN_SYMBOL) {
			invalid(L, LS, "Need a key/value seprator");
		}
		read_token(L, LS);
		push_value(L, LS, layer);
		return 1;
	}
	default:
		invalid(L, LS, "Invalid token in a list");
		return 0;
	}
}

static void
check_close_bracket(lua_State *L, struct lex_state *LS, int bracket) {
	if (LS->t.type != TOKEN_BRACKET)
		invalid(L, LS, "Need close bracket");
	int close_bracket = token_symbol(LS);
	switch (bracket) {
	case '{':
		if (close_bracket == '}')
			return;
		break;
	case '[':
		if (close_bracket == ']')
			return;
		break;
	default:
		// never be here
		break;
	}
	invalid(L, LS, "Invalid close bracket");
}

static void
parse_map(lua_State *L, struct lex_state *LS, int layer) {
	new_table(L, layer);
	int bracket = token_symbol(LS);
	if (try_kv(L, LS, layer)) {
		lua_settable(L, -3);
		while (parse_kv(L, LS, layer)) {
			lua_settable(L, -3);
		}
	}
	check_close_bracket(L, LS, bracket);
}

static void
parse_list(lua_State *L, struct lex_state *LS, int layer) {
	new_table(L, layer);
	int bracket = token_symbol(LS);
	if (try_kv(L, LS, layer)) {
		int n = 1;
		pair_seti(L, n);
		while (parse_kv(L, LS, layer)) {
			pair_seti(L, ++n);
		}
	}
	check_close_bracket(L, LS, bracket);
}

static void
push_value(lua_State *L, struct lex_state *LS, int layer) {
	switch(LS->t.type) {
	case TOKEN_BRACKET:
		switch (token_symbol(LS)) {
		case '{':
			parse_map(L, LS, layer+1);
			break;
		case '[':
			parse_list(L, LS, layer+1);
			break;
		default:
			// never be here
			invalid(L, LS, "Invalid bracket");
			break;
		}
		break;
	case TOKEN_LAYER:
		invalid(L, LS, "Invalid layer symbol");
		break;
	case TOKEN_SYMBOL:
		invalid(L, LS, "Invalid separtor symbol");
		break;
	default:
		push_token(L, LS, &LS->t);
		break;
	}
}

static void parse_section_map(lua_State *L, struct lex_state *LS, int layer);
static void parse_section_list(lua_State *L, struct lex_state *LS, int layer);

static int
read_subsection(lua_State *L, struct lex_state *LS, int layer) {
	int sublayer = layer_depth(LS);
	if (sublayer <= layer)
		return 0;
	if (sublayer != layer + 1) {
		invalid(L, LS, "Invalid layer");
	}
	char layer_symbol = token_symbol(LS);	// * or #
	if (read_token(L, LS) != TOKEN_ATOM) {
		invalid(L, LS, "Need layer name");
	}
	push_key(L, LS, &LS->t);
	switch (layer_symbol) {
	case '#':
		parse_section_map(L, LS, sublayer);
		break;
	case '*':
		parse_section_list(L, LS, sublayer);
		break;
	default:
		// never be here
		invalid(L, LS, "Invalid layer symbol");
		break;
	}
	return 1;
}

static int
try_subsection_kv_(lua_State *L, struct lex_state *LS, int layer, int t) {
	switch (t) {
	case TOKEN_EOF:
		return 0;
	case TOKEN_LAYER:
		return read_subsection(L, LS, layer);
	case TOKEN_ATOM:
		if (read_first_kv(L, LS, layer)) {
			// consume last token, because parse_section_kv don't read it
			read_token(L, LS);
			return 1;
		} else {
			return 0;
		}
	default:
		push_value(L, LS, layer);
		lua_seti(L, -2, 1);
		parse_seq(L, LS, layer, 2);
		return 0;
	}
}

static int
try_subsection_kv(lua_State *L, struct lex_state *LS, int layer) {
	int t = read_token(L, LS);
	if (t == TOKEN_SYMBOL) {
		// one value
		read_token(L, LS);
		push_value(L, LS, layer);
		read_token(L, LS);
		return 0;
	}
	new_table(L, layer);
	return try_subsection_kv_(L, LS, layer, t);
}

static int
parse_section_kv(lua_State *L, struct lex_state *LS, int layer) {
	switch (LS->t.type) {
	case TOKEN_EOF:
		return 0;
	case TOKEN_LAYER:
		return read_subsection(L, LS, layer);
	case TOKEN_ATOM: {
		push_key(L, LS, &LS->t);
		if (read_token(L, LS) != TOKEN_SYMBOL) {
			invalid(L, LS, "Need a key/value seprator in a section");
		}
		read_token(L, LS);
		push_value(L, LS, layer);
		// consume value
		read_token(L, LS);
		return 1;
	}
	default:
		invalid(L, LS, "Invalid sub section");
		return 0;
	}
}

static inline void
parse_section_map_rest(lua_State *L, struct lex_state *LS, int layer) {
	lua_settable(L, -3);
	while (parse_section_kv(L, LS, layer)) {
		lua_settable(L, -3);
	}
}

static void
parse_section_map(lua_State *L, struct lex_state *LS, int layer) {
	if (!try_subsection_kv(L, LS, layer)) {
		return;
	}
	parse_section_map_rest(L, LS, layer);
}

static void
parse_section_list_rest(lua_State *L, struct lex_state *LS, int layer) {
	int n = 1;
	pair_seti(L, n);
	while (parse_section_kv(L, LS, layer)) {
		pair_seti(L, ++n);
	}
}

static void
parse_section_list(lua_State *L, struct lex_state *LS, int layer) {
	if (!try_subsection_kv(L, LS, layer)) {
		return;
	}
	parse_section_list_rest(L, LS, layer);
}

static void
parse_section_map_top(lua_State *L, struct lex_state *LS) {
	// result table is create outside
	if (!try_subsection_kv_(L, LS, 0, read_token(L, LS))) {
		return;
	}
	parse_section_map_rest(L, LS, 0);
}

static void
parse_section_list_top(lua_State *L, struct lex_state *LS) {
	// result table is create outside
	if (!try_subsection_kv_(L, LS, 0, read_token(L, LS))) {
		return;
	}
	parse_section_list_rest(L, LS, 0);
}

static void
init_lex(lua_State *L, int index, struct lex_state *LS) {
	LS->source = luaL_checklstring(L, 1, &LS->sz);
	LS->position = 0;
}

static void
check_eof(lua_State *L, struct lex_state *LS) {
	if (LS->t.type != TOKEN_EOF) {
		invalid(L, LS, "not end");
	}
}

static int
lparse(lua_State *L) {
	struct lex_state LS;
	init_lex(L, 1, &LS);
	int t = lua_type(L, 2);
	if (t == LUA_TTABLE || t == LUA_TUSERDATA) {
		lua_settop(L, 2);
		parse_section_map_top(L, &LS);
	} else {
		parse_section_map(L, &LS, 0);
	}
	check_eof(L, &LS);

	return 1;
}

static int
lparse_list(lua_State *L) {
	struct lex_state LS;
	init_lex(L, 1, &LS);
	int t = lua_type(L, 2);
	if (t == LUA_TTABLE || t == LUA_TUSERDATA) {
		lua_settop(L, 2);
		parse_section_list_top(L, &LS);
	} else {
		parse_section_list(L, &LS, 0);
	}
	check_eof(L, &LS);

	return 1;
}

static int
ltoken(lua_State *L) {
	struct lex_state LS;
	LS.source = luaL_checklstring(L, 1, &LS.sz);
	LS.position = 0;

	lua_newtable(L);

	int n = 1;
	while(next_token(&LS)) {
		if (LS.t.type == TOKEN_EOF) {
			return 1;
		}
		lua_pushlstring(L, LS.source + LS.t.from, LS.t.to - LS.t.from);
		lua_seti(L, -2, n++);
	}
	return invalid(L, &LS, "Invalid token");
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
