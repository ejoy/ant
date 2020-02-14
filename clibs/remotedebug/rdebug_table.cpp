#include "rdebug_table.h"
#include <lapi.h>
#include <lgc.h>
#include <lobject.h>
#include <lstate.h>
#include <ltable.h>

namespace remotedebug::table {

#if LUA_VERSION_NUM < 504
#define s2v(o) (o)
#endif


static unsigned int array_limit(const Table* t) {
#if LUA_VERSION_NUM >= 504
    if ((!(t->marked & BITRAS) || (t->alimit & (t->alimit - 1)) == 0)) {
        return t->alimit;
    }
    unsigned int size = t->alimit;
    size |= (size >> 1);
    size |= (size >> 2);
    size |= (size >> 4);
    size |= (size >> 8);
    size |= (size >> 16);
#if (UINT_MAX >> 30) > 3
    size |= (size >> 32);
#endif
    size++;
    return size;
#else
    return t->sizearray;
#endif
}

unsigned int array_size(const void* tv) {
	const Table* t = (const Table*)tv;
	unsigned int alimit = array_limit(t);
	if (alimit) {
		for (unsigned int i = alimit; i > 0; --i) {
			if (!ttisnil(&t->array[i-1])) {
				return i;
			}
		}
	}
	return 0;
}

unsigned int hash_size(const void* tv) {
	const Table* t = (const Table*)tv;
	return (unsigned int)(1<<t->lsizenode);
}

int get_kv(lua_State* L, const void* tv, unsigned int i) {
	const Table* t = (const Table*)tv;
	Node* n = &t->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	L->top += 2;
	StkId key = L->top - 1;
	StkId val = L->top - 2;
#if LUA_VERSION_NUM >= 504
	getnodekey(L, s2v(key), n);
#else
	setobj2s(L, key, &n->i_key.tvk);
#endif
	setobj2s(L, val, gval(n));
	return 1;
}

int get_k(lua_State* L, int idx, unsigned int i) {
	const Table* t = (const Table*)lua_topointer(L, idx);
	if (!t) {
		return 0;
	}
	if (i >= hash_size(t)) {
		return 0;
	}
	Node* n = &t->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	StkId key = L->top;
#if LUA_VERSION_NUM >= 504
	getnodekey(L, s2v(key), n);
#else
	setobj2s(L, key, &n->i_key.tvk);
#endif
	L->top++;
	return 1;
}

int get_v(lua_State* L, int idx, unsigned int i) {
	const Table* t = (const Table*)lua_topointer(L, idx);
	if (!t) {
		return 0;
	}
	if (i >= hash_size(t)) {
		return 0;
	}
	Node* n = &t->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	setobj2s(L, L->top, gval(n));
	L->top++;
	return 1;
}

int set_v(lua_State* L, int idx, unsigned int i) {
	const Table* t = (const Table*)lua_topointer(L, idx);
	if (!t) {
		return 0;
	}
	if (i >= hash_size(t)) {
		return 0;
	}
	Node* n = &t->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	setobj2t(L, gval(n), s2v(L->top - 1));
	L->top--;
	return 1;
}

}
