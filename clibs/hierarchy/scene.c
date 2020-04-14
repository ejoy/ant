#define LUA_LIB
#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <string.h>

#define MAXIDBITS 32
#define MAXID (((lua_Integer)1<<MAXIDBITS)-1)
#define TEMPARRAY 256

#define QUEUE 1
#define OBJID 2
#define RESULT_TABLE 2
#define PARENTID 3
#define INDEX lua_upvalueindex(1)

#ifdef lua_newuserdata
// lua 5.4
#undef lua_newuserdata
#define lua_newuserdata(L, sz) lua_newuserdatauv(L, sz, 0)
#endif

#define printf(...)

static inline int
get_parent(lua_Integer v) {
	return v & MAXID;
}

static inline int
get_position(lua_Integer v) {
	return (int)(v >> MAXIDBITS);
}

static inline lua_Integer
make_index(int parent, int position) {
	return (lua_Integer)parent | (lua_Integer)position << MAXIDBITS;
}

// queue table : [ A B C D E F ]
// index table : [ A-> index (position << MAXIDBITS | parent), ...]   
//
//               A   B
//              /|   |
//             C D   E
//                   |
//                   F
//
// queue [ 1:A 2:B 3:C 4:D 5:E 6:F ]
// index [ A:(1,0) B:(2,0) C:(3,A) D:(4,A) E:(5,B) F:(6,D) ]

static int
get_index(lua_State *L, int value) {
	int result;
	if (lua_rawgeti(L, INDEX, value) == LUA_TNIL) {
		// not exist
		int n = lua_rawlen(L, QUEUE);
		result = n+1;
		lua_pushinteger(L, value);
		lua_rawseti(L, QUEUE, result);	// push queue

		lua_pushinteger(L, make_index(0, result));	// parent is root (0)
		lua_rawseti(L, INDEX, value);	// set index
	} else {
		lua_Integer index = lua_tointeger(L, -1);
		result = get_position(index);
	}
	lua_pop(L, 1);
	return result;
}

struct array {
	int *array;
	lua_State *L;
	int temp[TEMPARRAY];
	int size;
	int cap;
	int buffer_index;
};

static void
array_init(struct array *a, lua_State *L) {
	a->array = a->temp;
	a->L = L;
	a->size = 0;
	a->cap = TEMPARRAY;
	a->buffer_index = 0;
}

static inline lua_Integer
get_integer(lua_State *L, int table, int index) {
	lua_rawgeti(L, table, index);
	lua_Integer v = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return v;
}

static void
move_position(lua_State *L, int v, int new_position) {
	// move v to new position, change index in INDEX table
	lua_Integer index = get_integer(L, INDEX, v);
	lua_Integer new_index = make_index(get_parent(index), new_position);
	printf("move %d^%d(at %d)\n", v, get_parent(index), new_position);
	lua_pushinteger(L, new_index);
	lua_rawseti(L, INDEX, v);
}

static void
array_push(struct array *a, int v) {
	if (a->size >= a->cap) {
		a->cap = a->size * 2;
		int * old_array = a->array;
		a->array = (int *)lua_newuserdata(a->L, a->cap * sizeof(int));
		memcpy(a->array, old_array, a->size * sizeof(int));
		if (a->buffer_index == 0) {
			a->buffer_index = lua_gettop(a->L);
		} else {
			lua_replace(a->L, a->buffer_index);
		}
	}
	a->array[a->size] = v;
	a->size++;
}

static int
lqueue_mount(lua_State *L) {
	luaL_checktype(L, QUEUE, LUA_TTABLE);
	int id = luaL_checkinteger(L, OBJID);
	if (id <= 0 || id > MAXID)
		return luaL_error(L, "Invalid entity id %d (must > 0)", id);
	if (lua_isnoneornil(L, PARENTID)) {
		if (lua_rawgeti(L, INDEX, id) == LUA_TNIL) {
			// not exist
			return 0;
		}
		// remove id
		int position = get_position(lua_tointeger(L, -1));
		lua_pushinteger(L, make_index(0, position));
		lua_rawseti(L, INDEX, id);
		lua_pushboolean(L, 0);
		lua_rawseti(L, QUEUE, position);
		return 0;
	}
	int parent = luaL_checkinteger(L, PARENTID);
	if (parent < 0 || parent > MAXID)
		return luaL_error(L, "Invalid parent id %d (must >= 0)", parent);

	if (parent == 0) {
		int position;
		if (lua_rawgeti(L, INDEX, id) == LUA_TNIL) {
			// not exist
			position = lua_rawlen(L, QUEUE) + 1;
		} else {
			position = get_position(lua_tointeger(L, -1));
		}
		lua_pushinteger(L, make_index(0, position));
		lua_rawseti(L, INDEX, id);
		lua_pushvalue(L, OBJID);
		lua_rawseti(L, QUEUE, position);
		return 0;
	}

	int obj_index = get_index(L, id);
	int parent_index = get_index(L, parent);

	lua_pushinteger(L, make_index(parent, obj_index));
	lua_rawseti(L, INDEX, id);

	if (obj_index > parent_index)
		return 0;

	// reorder
	// [... obj A B C D parent ... ]
	//      ^            ^           ^
	//    obj_index     parent_index queue_len
	//    head_index                 tail_index
	//
	//  1. push parent and obj int temp array, and the index or them point to tail_index
	//       [ ... _ A B C D _ ... ]  [ parent obj ]
	//  2. for each v in [ A B C D ] 
	//     if parent of v is in temp array, (index > queue_len) then push back temp array
	//           [ ... _ _ B C D _ ... ] [ parent obj A ]
	//     else move v to head_index
	//           [ ... A _ B C D _ ... ] [ parent obj ]
	//  3. move temp array after head_index
	//           [ ... A B C D parent obj ... ] 

	struct array A;
	array_init(&A, L);
	int queue_len = lua_rawlen(L, QUEUE);
	int head_index = obj_index;
	int tail_index = queue_len;

	printf("(%d - %d)\n", obj_index, parent_index);

	array_push(&A, parent);
	move_position(L, parent, ++tail_index);

	array_push(&A, id);
	move_position(L, id, ++tail_index);

	int i;
	for (i=obj_index+1;i<=parent_index-1;i++) {
		int v = get_integer(L, QUEUE, i);
		int parent = get_parent(get_integer(L, INDEX, v));
		if (parent != 0 && get_position(get_integer(L, INDEX, parent)) > queue_len) {
			printf(">> ");
			array_push(&A, v);
			move_position(L, v, ++tail_index);
		} else {
			printf("<< ");
			lua_pushinteger(L, v);
			lua_rawseti(L, QUEUE, head_index);
			move_position(L, v, head_index);
			++head_index;
		}
	}
	for (i=0;i<A.size;i++) {
		int v = A.array[i];
		lua_pushinteger(L, v);
		lua_rawseti(L, QUEUE, head_index);
		move_position(L, v, head_index);
		++head_index;
	}
	
	return 0;
}

static int
remove_from_index(lua_State *L) {
	int result_n = 0;
	if (lua_istable(L, RESULT_TABLE)) {
		result_n = 1;
	}
	lua_pushnil(L);
	while (lua_next(L, INDEX) != 0) {
		int pos = get_position(lua_tointeger(L, -1));
		lua_pop(L, 1);	// pop value (index)
		int key = lua_tointeger(L, -1);
		if (lua_rawgeti(L, QUEUE, pos) != LUA_TNUMBER) {
			// remove from index
			printf("remove %d from index table\n", key);
			if (result_n) {
				lua_pushinteger(L, key);
				lua_rawseti(L, RESULT_TABLE, result_n++);
			}
			lua_pop(L, 1);
			lua_pushnil(L);
			lua_rawseti(L, INDEX, key);
		} else {
			lua_pop(L, 1);	// pop QUEUE[pos]
		}
	}
	return result_n;
}

static int
parent_exist(lua_State *L, int id) {
	int parent_id = get_parent(get_integer(L, INDEX, id));
	if (parent_id == 0)	// root always exist
		return 1;		 
	if (lua_rawgeti(L, INDEX, parent_id) != LUA_TNIL) {
		lua_pop(L, 1);
		return 1;
	}
	lua_pop(L, 1);

	printf("parent disappear, remove %d from index table\n", id);

	// remove from index table
	lua_pushnil(L);
	lua_rawseti(L, INDEX, id);

	return 0;
}

static int
lqueue_clear(lua_State *L) {
	int result_n = remove_from_index(L);
	int n = lua_rawlen(L, QUEUE);
	int i, head;
	for (head=i=1;i<=n;i++) {
		int id;
		int type;
		if ((type=lua_rawgeti(L, QUEUE, i)) == LUA_TNUMBER && parent_exist(L, (id = lua_tointeger(L, -1)))) {
			if (head != i) {
				lua_rawseti(L, QUEUE, head);
				move_position(L, id, head);
			} else {
				lua_pop(L, 1);
			}
			++head;
		} else {
			if (result_n && type == LUA_TNUMBER) {
				lua_rawseti(L, RESULT_TABLE, result_n++);
			} else {
				lua_pop(L, 1);
			}
		}
	}
	for (i=head;i<=n;i++) {
		lua_pushnil(L);
		lua_rawseti(L, QUEUE, i);
	}
	if (result_n > 1) {
		lua_settop(L, RESULT_TABLE);
		return 1;
	} else {
		return 0;
	}
}

#undef QUEUE
#undef OBJID
#undef PARENTID
#undef INDEX

static int
lqueue(lua_State *L) {
	lua_newtable(L);
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);
	return 1;
}

static void
queue(lua_State *L) {
	luaL_Reg meta[] = {
		{ "__index", NULL },
		{ "mount" , lqueue_mount },
		{ "clear", lqueue_clear },
		{ NULL, NULL },
	};
	lua_newtable(L);	// index table

	luaL_newlibtable(L, meta);
	luaL_setfuncs(L, meta, 1);

	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	lua_pushcclosure(L, lqueue, 1);
}

LUAMOD_API int
luaopen_hierarchy_scene(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = {
		{ "queue", NULL },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	queue(L);
	lua_setfield(L, -2, "queue");

	return 1;
}
