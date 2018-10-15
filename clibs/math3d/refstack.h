#ifndef linear_algebra_refstack_h
#define linear_algebra_refstack_h

#include <lua.h>
#include <lauxlib.h>

#define MAX_REF_STACK 128

struct ref_slot {
	int stack_id;
	int lua_id;
};

struct ref_stack {
	int top;
	int reftop;
	lua_State *L;
	struct ref_slot s[MAX_REF_STACK];
};

static inline void
refstack_init(struct ref_stack *RS, lua_State *L) {
	RS->top = 0;
	RS->reftop = 0;
	RS->L = L;
}

static inline void
refstack_push(struct ref_stack *RS) {
	++RS->top;
}

static inline void
refstack_pop(struct ref_stack *RS) {
	--RS->top;
	if (RS->reftop > 0) {
		if (RS->s[RS->reftop-1].stack_id == RS->top) {
			--RS->reftop;
		}
	}
}

static inline void
refstack_2_1(struct ref_stack *RS) {
	refstack_pop(RS);
	refstack_pop(RS);
	refstack_push(RS);
}

static inline void
refstack_1_1(struct ref_stack *RS) {
	refstack_pop(RS);
	refstack_push(RS);
}

static inline void
refstack_pushref(struct ref_stack *RS, int lua_id) {
	if (lua_id < 0) {
		refstack_push(RS);
		return;
	}
	if (RS->reftop >= MAX_REF_STACK)
		luaL_error(RS->L, "ref stack overflow");
	struct ref_slot *s = &RS->s[RS->reftop++]; 
	s->stack_id = RS->top++;
	s->lua_id = lua_id;
}

static inline int
refstack_topid(struct ref_stack *RS) {
	if (RS->reftop > 0) {
		struct ref_slot *s = &RS->s[RS->reftop-1]; 
		if (s->stack_id == RS->top-1) {
			return s->lua_id;
		}
	}
	return -1;
}

static inline void
refstack_swap(struct ref_stack *RS) {
	int top = refstack_topid(RS);
	refstack_pop(RS);
	int newtop = refstack_topid(RS);
	refstack_pop(RS);
	refstack_pushref(RS, top);
	refstack_pushref(RS, newtop);
}

static inline void
refstack_dup(struct ref_stack *RS, int index) {
	int i;
	int lua_id = -1;
	int stack_id = RS->top - index;
	for (i=RS->reftop-1;i>=0;i--) {
		struct ref_slot *s = &RS->s[i];
		if (s->stack_id == stack_id) {
			lua_id = s->lua_id;
			break;
		}
		if (s->stack_id < stack_id)
			break;
	}
	refstack_pushref(RS, lua_id);
}

#endif
