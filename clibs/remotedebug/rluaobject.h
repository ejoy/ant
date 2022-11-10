#pragma once
#ifdef LUAJIT_VERSION
#include <lj_obj.h>
#include <lj_tab.h>
using Table= GCtab;
using Closure = GCfunc;
using UpVal = GCupval;
using Proto = GCproto;
using UDate = GCudata;
using TString = GCstr;
using StkId = TValue*;

static TValue *index2adr(lua_State *L, int idx)
{
  if (idx > 0) {
    TValue *o = L->base + (idx - 1);
    return o < L->top ? o : niltv(L);
  } else if (idx > LUA_REGISTRYINDEX) {
    lj_checkapi(idx != 0 && -idx <= L->top - L->base,
		"bad stack slot %d", idx);
    return L->top + idx;
  } else if (idx == LUA_GLOBALSINDEX) {
    TValue *o = &G(L)->tmptv;
    settabV(L, o, tabref(L->env));
    return o;
  } else if (idx == LUA_REGISTRYINDEX) {
    return registry(L);
  } else {
    GCfunc *fn = curr_func(L);
    lj_checkapi(fn->c.gct == ~LJ_TFUNC && !isluafunc(fn),
		"calling frame is not a C function");
    if (idx == LUA_ENVIRONINDEX) {
      TValue *o = &G(L)->tmptv;
      settabV(L, o, tabref(fn->c.env));
      return o;
    } else {
      idx = LUA_GLOBALSINDEX - idx;
      return idx <= fn->c.nupvalues ? &fn->c.upvalue[idx-1] : niltv(L);
    }
  }
}
static int lua_isinteger (lua_State *L, int idx) {
  cTValue *o = index2adr(L, idx);
  return tvisint(o);
}
#else
#include <lapi.h>
#include <lgc.h>
#include <lobject.h>
#include <lstate.h>
#include <ltable.h>
#endif
