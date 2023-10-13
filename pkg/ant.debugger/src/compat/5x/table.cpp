#include "compat/table.h"

#include <lstate.h>
#include <ltable.h>

#include "compat/lua.h"

namespace luadebug::table {

#if LUA_VERSION_NUM < 504
#    define s2v(o) (o)
#endif

    template <typename T>
    StkId& LUA_STKID(T& s) {
#if LUA_VERSION_NUM >= 504
        return s.p;
#else
        return s;
#endif
    }

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
#    if (UINT_MAX >> 30) > 3
        size |= (size >> 32);
#    endif
        size++;
        return size;
#else
        return t->sizearray;
#endif
    }

    unsigned int array_size(const void* tv) {
        const Table* t      = (const Table*)tv;
        unsigned int alimit = array_limit(t);
        if (alimit) {
            for (unsigned int i = alimit; i > 0; --i) {
                if (!ttisnil(&t->array[i - 1])) {
                    return i;
                }
            }
        }
        return 0;
    }

    unsigned int hash_size(const void* tv) {
        const Table* t = (const Table*)tv;
        return (unsigned int)(1 << t->lsizenode);
    }

    bool array_base_zero() {
        return false;
    }

    bool get_hash_kv(lua_State* L, const void* tv, unsigned int i) {
        const Table* t = (const Table*)tv;
        Node* n        = &t->node[i];
        if (ttisnil(gval(n))) {
            return false;
        }
        LUA_STKID(L->top) += 2;
        StkId key = LUA_STKID(L->top) - 1;
        StkId val = LUA_STKID(L->top) - 2;
#if LUA_VERSION_NUM >= 504
        getnodekey(L, s2v(key), n);
#else
        setobj2s(L, key, &n->i_key.tvk);
#endif
        setobj2s(L, val, gval(n));
        return true;
    }

    bool get_hash_k(lua_State* L, const void* tv, unsigned int i) {
        const Table* t = (const Table*)tv;
        if (i >= hash_size(t)) {
            return false;
        }
        Node* n = &t->node[i];
        if (ttisnil(gval(n))) {
            return false;
        }
        StkId key = LUA_STKID(L->top);
#if LUA_VERSION_NUM >= 504
        getnodekey(L, s2v(key), n);
#else
        setobj2s(L, key, &n->i_key.tvk);
#endif
        LUA_STKID(L->top) += 1;
        return true;
    }

    bool get_hash_v(lua_State* L, const void* tv, unsigned int i) {
        const Table* t = (const Table*)tv;
        if (i >= hash_size(t)) {
            return false;
        }
        Node* n = &t->node[i];
        if (ttisnil(gval(n))) {
            return false;
        }
        setobj2s(L, LUA_STKID(L->top), gval(n));
        LUA_STKID(L->top) += 1;
        return true;
    }

    bool set_hash_v(lua_State* L, const void* tv, unsigned int i) {
        const Table* t = (const Table*)tv;
        if (i >= hash_size(t)) {
            return false;
        }
        Node* n = &t->node[i];
        if (ttisnil(gval(n))) {
            return false;
        }
        setobj2t(L, gval(n), s2v(LUA_STKID(L->top) - 1));
        LUA_STKID(L->top) -= 1;
        return true;
    }

    bool get_array(lua_State* L, const void* tv, unsigned int i) {
        const Table* t = (const Table*)tv;
        if (i >= array_limit(t)) {
            return false;
        }
        TValue* value = &t->array[i];
        setobj2s(L, LUA_STKID(L->top), value);
        LUA_STKID(L->top) += 1;
        return true;
    }

    bool set_array(lua_State* L, const void* tv, unsigned int i) {
        const Table* t = (const Table*)tv;
        if (i >= array_limit(t)) {
            return false;
        }
        TValue* value = &t->array[i];
        setobj2t(L, value, s2v(LUA_STKID(L->top) - 1));
        LUA_STKID(L->top) -= 1;
        return true;
    }
}
