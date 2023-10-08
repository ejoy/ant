#include <lj_cdata.h>
#include <lj_ctype.h>
#include <lj_obj.h>

#include "compat/lua.h"

TValue* index2adr(lua_State* L, int idx) {
    if (idx > 0) {
        TValue* o = L->base + (idx - 1);
        return o < L->top ? o : niltv(L);
    }
    else if (idx > LUA_REGISTRYINDEX) {
        lj_checkapi(idx != 0 && -idx <= L->top - L->base, "bad stack slot %d", idx);
        return L->top + idx;
    }
    else if (idx == LUA_GLOBALSINDEX) {
        TValue* o = &G(L)->tmptv;
        settabV(L, o, tabref(L->env));
        return o;
    }
    else if (idx == LUA_REGISTRYINDEX) {
        return registry(L);
    }
    else {
        GCfunc* fn = curr_func(L);
        lj_checkapi(fn->c.gct == ~LJ_TFUNC && !isluafunc(fn), "calling frame is not a C function");
        if (idx == LUA_ENVIRONINDEX) {
            TValue* o = &G(L)->tmptv;
            settabV(L, o, tabref(fn->c.env));
            return o;
        }
        else {
            idx = LUA_GLOBALSINDEX - idx;
            return idx <= fn->c.nupvalues ? &fn->c.upvalue[idx - 1] : niltv(L);
        }
    }
}

const char* lua_cdatatype(lua_State* L, int idx) {
    cTValue* o  = index2adr(L, idx);
    GCcdata* cd = cdataV(o);
    if (cd->ctypeid == CTID_CTYPEID) {
        return "ctype";
    }
    else {
        return "cdata";
    }
}

const void* lua_tocfunction_pointer(lua_State* L, int idx) {
    cTValue* o      = index2adr(L, idx);
    const void* cfn = nullptr;
    if (tvisfunc(o)) {
        GCfunc* fn = funcV(o);
        cfn        = (const void*)(isluafunc(fn) ? NULL : fn->c.f);
    }
    else if (tviscdata(o)) {
        GCcdata* cd  = cdataV(o);
        CTState* cts = ctype_cts(L);
        if (cd->ctypeid != CTID_CTYPEID) {
            cfn = cdataptr(cd);
            if (cfn) {
                CType* ct = ctype_get(cts, cd->ctypeid);
                if (ctype_isref(ct->info) || ctype_isptr(ct->info)) {
                    cfn = cdata_getptr((void*)cfn, ct->size);
                    ct  = ctype_rawchild(cts, ct);
                }
                if (!ctype_isfunc(ct->info)) {
                    cfn = nullptr;
                }
                else if (cfn) {
                    cfn = cdata_getptr((void*)cfn, ct->size);
                }
            }
        }
    }
    return cfn;
}

int lua_isinteger(lua_State* L, int idx) {
    cTValue* o = index2adr(L, idx);
    return tvisint(o);
}
