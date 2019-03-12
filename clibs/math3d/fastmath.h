#ifndef math_fastcall_h
#define math_fastcall_h

#include <lua.h>
#include "linalg.h"
#include "refstack.h"

typedef int (*MFunction)(lua_State *L, struct lastack *LS, struct ref_stack *RS);

#define FASTMATH(f)\
int m_##f(lua_State *L, struct lastack *LS_, struct ref_stack *RS_) {\
	struct ref_stack tmpRS; \
	struct lastack *LS;\
	struct ref_stack *RS;\
	if (L == NULL) {\
		L = RS_->L; LS=LS_; RS=RS_; (void)LS; (void)RS;\
	} else {\
		LS = getLS(L, 1); refstack_init(&tmpRS, L); RS = &tmpRS;\
	}

#define MFUNCTION(f) #f, (lua_CFunction)( m_##f )

#endif
