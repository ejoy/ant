#include "rdebug_table.h"
#include "rluaobject.h"


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
#elif defined(LUAJIT_VERSION)
	return t->asize;
#else
    return t->sizearray;
#endif
}

unsigned int array_size(const void* tv) {
	const Table* t = (const Table*)tv;
	unsigned int alimit = array_limit(t);
	if (alimit) {
		for (unsigned int i = alimit; i > 0; --i) {
#ifdef LUAJIT_VERSION
			TValue* arr = tvref(t->array);
			if (!tvisnil(&arr[i-1])) {
				return i-1;
			}
#else
			if (!ttisnil(&t->array[i-1])) {
				return i;
			}
#endif

		}
	}
	return 0;
}

unsigned int hash_size(const void* tv) {
	const Table* t = (const Table*)tv;
#ifdef LUAJIT_VERSION
	if (t->hmask <= 0) return 0;
	return t->hmask + 1;
#else
	return (unsigned int)(1<<t->lsizenode);
#endif
}

 bool has_zero(const void* tv) {
#ifdef LUAJIT_VERSION
	const Table* t = (const Table*)tv;
	return t->asize > 0 && !tvisnil(arrayslot(t, 0));
#else
	return false;
#endif
 }

int get_zero(lua_State* L, const void* tv) {
#ifdef LUAJIT_VERSION
	const Table* t = (const Table*)tv;
	if (t->asize == 0){
		return 0;
	}
	TValue* v = arrayslot(t, 0);
	if (tvisnil(v)) {
		return 0;
	}
	L->top += 2;
	StkId key = L->top - 1;
	StkId val = L->top - 2;
	setintptrV(key, 0);
	copyTV(L,val, v);
	return 1;
#endif
	return 0;
}

int get_kv(lua_State* L, const void* tv, unsigned int i) {
	const Table* t = (const Table*) tv;

#ifdef LUAJIT_VERSION
	Node* node = noderef(t->node);
	Node* n = &node[i];
	if(tvisnil(&n->val))
	{
		return 0;
	}
	L->top += 2;
	StkId key = L->top - 1;
	StkId val = L->top - 2;
	copyTV(L,key, &n->key);
	copyTV(L,val, &n->val);
#else
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
#endif
	return 1;
}

int get_k(lua_State* L, const void* t, unsigned int i) {
	if (i >= hash_size(t)) {
		return 0;
	}
#ifdef LUAJIT_VERSION
	const Table* ct = (const Table*)t;
	Node* node = noderef(ct->node);
	Node* n = &node[i];
	if(tvisnil(&n->val))
	{
		return 0;
	}
	StkId key = L->top;
	copyTV(L,key,&n->key);
#else
	Node* n = &((const Table*)t)->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	StkId key = L->top;
#if LUA_VERSION_NUM >= 504
	getnodekey(L, s2v(key), n);
#else
	setobj2s(L, key, &n->i_key.tvk);
#endif
#endif
	L->top++;
	return 1;
}

int get_k(lua_State* L, int idx, unsigned int i) {
#ifdef LUAJIT_VERSION
	const GCtab* t = &((const GCobj*)lua_topointer(L, idx))->tab;
#else
	const void* t = lua_topointer(L,idx);
#endif
	if (!t) {
		return 0;
	}
	return get_k(L, t, i);
}

int get_v(lua_State* L, int idx, unsigned int i) {
#ifdef LUAJIT_VERSION
	const GCtab* t = &((const GCobj*)lua_topointer(L, idx))->tab;
#else
	const Table* t = (const Table*)lua_topointer(L, idx);
#endif
	if (!t) {
		return 0;
	}
	if (i >= hash_size(t)) {
		return 0;
	}
#ifdef LUAJIT_VERSION
	Node* node = noderef(t->node);
	Node* n = &node[i];
	if(tvisnil(&n->val))
	{
		return 0;
	}
	copyTV(L,L->top,&n->val);
#else
	Node* n = &t->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	setobj2s(L, L->top, gval(n));
#endif
	L->top++;
	return 1;
}

int set_v(lua_State* L, int idx, unsigned int i) {
#ifdef LUAJIT_VERSION
	const GCtab* t = &((const GCobj*)lua_topointer(L, idx))->tab;
#else
	const Table* t = (const Table*)lua_topointer(L, idx);
#endif
	if (!t) {
		return 0;
	}
	if (i >= hash_size(t)) {
		return 0;
	}

#ifdef LUAJIT_VERSION
	Node* node = noderef(t->node);
	Node* n = &node[i];
	if(tvisnil(&n->val))
	{
		return 0;
	}
	copyTV(L,&n->val,L->top - 1);
#else
	Node* n = &t->node[i];
	if (ttisnil(gval(n))) {
		return 0;
	}
	setobj2t(L, gval(n), s2v(L->top - 1));
#endif
	L->top--;
	return 1;
}

}
