#include "compat/table.h"

#include <lj_tab.h>

#include "compat/lua.h"

namespace luadebug::table {

    static unsigned int array_limit(const GCtab* t) {
        return t->asize;
    }

    unsigned int array_size(const void* tv) {
        const GCtab* t      = &((const GCobj*)tv)->tab;
        unsigned int alimit = array_limit(t);
        if (alimit) {
            for (unsigned int i = alimit; i > 0; --i) {
                TValue* arr = tvref(t->array);
                if (!tvisnil(&arr[i - 1])) {
                    return i;
                }
            }
        }
        return 0;
    }

    unsigned int hash_size(const void* tv) {
        const GCtab* t = &((const GCobj*)tv)->tab;
        if (t->hmask <= 0) return 0;
        return t->hmask + 1;
    }

    bool array_base_zero() {
        return true;
    }

    bool get_hash_kv(lua_State* L, const void* tv, unsigned int i) {
        const GCtab* t = &((const GCobj*)tv)->tab;
        Node* node     = noderef(t->node);
        Node* n        = &node[i];
        if (tvisnil(&n->val)) {
            return false;
        }
        L->top += 2;
        TValue* key = L->top - 1;
        TValue* val = L->top - 2;
        copyTV(L, key, &n->key);
        copyTV(L, val, &n->val);
        return true;
    }

    bool get_hash_k(lua_State* L, const void* tv, unsigned int i) {
        if (i >= hash_size(tv)) {
            return false;
        }
        const GCtab* t = &((const GCobj*)tv)->tab;
        Node* node     = noderef(t->node);
        Node* n        = &node[i];
        if (tvisnil(&n->val)) {
            return false;
        }
        TValue* key = L->top;
        copyTV(L, key, &n->key);
        L->top += 1;
        return true;
    }

    bool get_hash_v(lua_State* L, const void* tv, unsigned int i) {
        const GCtab* t = &((const GCobj*)tv)->tab;
        if (i >= hash_size(t)) {
            return false;
        }
        Node* node = noderef(t->node);
        Node* n    = &node[i];
        if (tvisnil(&n->val)) {
            return false;
        }
        copyTV(L, L->top, &n->val);
        L->top += 1;
        return true;
    }

    bool set_hash_v(lua_State* L, const void* tv, unsigned int i) {
        const GCtab* t = &((const GCobj*)tv)->tab;
        if (i >= hash_size(t)) {
            return false;
        }
        Node* node = noderef(t->node);
        Node* n    = &node[i];
        if (tvisnil(&n->val)) {
            return false;
        }
        copyTV(L, &n->val, L->top - 1);
        L->top -= 1;
        return true;
    }

    bool get_array(lua_State* L, const void* tv, unsigned int i) {
        const GCtab* t = &((const GCobj*)tv)->tab;
        if (i >= array_limit(t)) {
            return false;
        }
        TValue* value = arrayslot(t, i);
        copyTV(L, L->top, value);
        L->top += 1;
        return true;
    }

    bool set_array(lua_State* L, const void* tv, unsigned int i) {
        const GCtab* t = &((const GCobj*)tv)->tab;
        if (i >= array_limit(t)) {
            return false;
        }
        TValue* value = arrayslot(t, i);
        copyTV(L, value, L->top - 1);
        L->top -= 1;
        return true;
    }
}
