#pragma once

#if !defined(RLUA_DISABLE)

#if !defined(RLUA_INTERNAL)

#include <stddef.h>
#include <stdio.h>

extern "C" {

struct rlua_State;
typedef ptrdiff_t rlua_KContext;
typedef int (*rlua_CFunction) (rlua_State *L);
typedef int (*rlua_KFunction) (rlua_State *L, int status, rlua_KContext ctx);

typedef long long rlua_Integer;
typedef unsigned long long rlua_Unsigned;
typedef double rlua_Number;

#define RLUA_REGISTRYINDEX	(-1000000/* LUAI_MAXSTACK */ - 1000)

struct rluaL_Reg {
  const char *name;
  rlua_CFunction func;
};

struct rluaL_Buffer {
    char *b;
    size_t size;
    size_t n;
    rlua_State *L;
    union {
        char b[8192];
    } init;
};

struct rluaL_Stream {
    FILE *f;
    rlua_CFunction closef;
};

rlua_State *(rluaL_newstate) (void);
void (rluaL_openlibs) (rlua_State *L);
int  (rluaL_loadstring) (rlua_State *L, const char *s);
int  (rluaL_loadbufferx) (rlua_State *L, const char *buff, size_t sz, const char *name, const char *mode);
void (rluaL_setfuncs) (rlua_State *L, const rluaL_Reg *l, int nup);
void (rluaL_checktype) (rlua_State *L, int arg, int t);
int  (rluaL_checkoption) (rlua_State *L, int arg, const char *def, const char *const lst[]);
void *(rluaL_checkudata) (rlua_State *L, int ud, const char *tname);
int   (rluaL_newmetatable) (rlua_State *L, const char *tname);
void  (rluaL_setmetatable) (rlua_State *L, const char *tname);
int (rluaL_callmeta) (rlua_State *L, int obj, const char *e);
const char *(rluaL_checklstring) (rlua_State *L, int arg, size_t *l);
rlua_Number  (rluaL_checknumber) (rlua_State *L, int arg);
rlua_Number  (rluaL_optnumber) (rlua_State *L, int arg, rlua_Number def);
rlua_Integer (rluaL_checkinteger) (rlua_State *L, int arg);
rlua_Integer (rluaL_optinteger) (rlua_State *L, int arg, rlua_Integer def);
rlua_Integer (rluaL_len) (rlua_State *L, int idx);
int (rluaL_argerror) (rlua_State *L, int arg, const char *extramsg);
int (rluaL_typeerror) (rlua_State *L, int arg, const char *tname);

void (rlua_close) (rlua_State *L);
int  (rlua_pcallk) (rlua_State *L, int nargs, int nresults, int errfunc, rlua_KContext ctx, rlua_KFunction k);
void (rlua_callk) (rlua_State *L, int nargs, int nresults, rlua_KContext ctx, rlua_KFunction k);
int  (rlua_type) (rlua_State *L, int idx);
const char *(rlua_typename) (rlua_State *L, int tp);
int  (rlua_error) (rlua_State *L);
int  (rluaL_error) (rlua_State *L, const char *fmt, ...);
void (rluaL_traceback) (rlua_State *L, rlua_State *L1, const char *msg, int level);
int  (rlua_gc) (rlua_State *L, int what, ...);

void *(rlua_newuserdatauv) (rlua_State *L, size_t sz, int nuvalue);
const char *(rlua_getupvalue) (rlua_State *L, int funcindex, int n);

void  (rlua_pushboolean) (rlua_State *L, int b);
void  (rlua_pushinteger) (rlua_State *L, rlua_Integer n);
void  (rlua_pushnumber) (rlua_State *L, rlua_Number n);
void  (rlua_pushlightuserdata) (rlua_State *L, void *p);
void  (rlua_pushcclosure) (rlua_State *L, rlua_CFunction fn, int n);
const char *(rlua_pushstring) (rlua_State *L, const char *s);
const char *(rlua_pushlstring) (rlua_State *L, const char *s, size_t len);
void  (rlua_pushnil) (rlua_State *L);
void  (rlua_pushvalue) (rlua_State *L, int idx);
const char *(rlua_pushfstring) (rlua_State *L, const char *fmt, ...);

int           (rlua_toboolean) (rlua_State *L, int idx);
const char *  (rlua_tolstring) (rlua_State *L, int idx, size_t *len);
void *        (rlua_touserdata) (rlua_State *L, int idx);
rlua_CFunction (rlua_tocfunction) (rlua_State *L, int idx);
rlua_Unsigned (rlua_rawlen) (rlua_State *L, int idx);
rlua_Number   (rlua_tonumberx) (rlua_State *L, int idx, int *isnum);
rlua_Integer  (rlua_tointegerx) (rlua_State *L, int idx, int *isnum);
int           (rlua_isinteger) (rlua_State *L, int idx);
int           (rlua_iscfunction) (rlua_State *L, int idx);

void (rlua_createtable) (rlua_State *L, int narr, int nrec);
void (rlua_rawsetp) (rlua_State *L, int idx, const void *p);
int  (rlua_rawgetp) (rlua_State *L, int idx, const void *p);
void (rlua_rawset) (rlua_State *L, int idx);
void (rlua_rawseti) (rlua_State *L, int idx, rlua_Integer n);
int  (rlua_rawgeti) (rlua_State *L, int idx, rlua_Integer n);
int  (rlua_setmetatable) (rlua_State *L, int objindex);
void (rlua_setfield) (rlua_State *L, int idx, const char *k);
int  (rlua_getiuservalue) (rlua_State *L, int idx, int n);
int  (rlua_setiuservalue) (rlua_State *L, int idx, int n);

int  (rlua_gettop) (rlua_State *L);
void (rlua_settop) (rlua_State *L, int idx);
void (rlua_rotate) (rlua_State *L, int idx, int n);
void (rlua_copy) (rlua_State *L, int fromidx, int toidx);
int  (rlua_checkstack) (rlua_State *L, int n);
void (rluaL_checkstack) (rlua_State *L, int sz, const char *msg);

void  (rluaL_buffinit) (rlua_State *L, rluaL_Buffer *B);
char *(rluaL_prepbuffsize) (rluaL_Buffer *B, size_t sz);
void  (rluaL_pushresultsize) (rluaL_Buffer *B, size_t sz);

#define rlua_pop(L,n) rlua_settop(L, -(n)-1)
#define rlua_pushcfunction(L,f) rlua_pushcclosure(L, (f), 0)
#define rlua_newuserdata(L,s) rlua_newuserdatauv(L,s,1)
#define rlua_newtable(L) rlua_createtable(L, 0, 0)
#define rlua_upvalueindex(i) (RLUA_REGISTRYINDEX - (i))
#define rlua_insert(L,idx) rlua_rotate(L, (idx), 1)
#define rluaL_checkstring(L,n) (rluaL_checklstring(L, (n), NULL))
#define rlua_setuservalue(L,idx) rlua_setiuservalue(L,idx,1)
#define rlua_getuservalue(L,idx) rlua_getiuservalue(L,idx,1)
#define rlua_replace(L,idx) (rlua_copy(L, -1, (idx)), rlua_pop(L, 1))
#define rlua_remove(L,idx) (rlua_rotate(L, (idx), -1), rlua_pop(L, 1))

#define rlua_tonumber(L,i) rlua_tonumberx(L,(i),NULL)
#define rlua_tointeger(L,i) rlua_tointegerx(L,(i),NULL)
#define rlua_tostring(L,i)	rlua_tolstring(L, (i), NULL)
#define rlua_call(L,n,r) rlua_callk(L, (n), (r), 0, NULL)
#define rlua_pcall(L,n,r,f) rlua_pcallk(L, (n), (r), (f), 0, NULL)
#define rluaL_loadbuffer(L,s,sz,n) rluaL_loadbufferx(L,s,sz,n,NULL)

}

#endif

#if !defined(RLUA_INTERNAL)
#include <lua.hpp>
#include "lua_compat.h"
#endif

#if defined(RLUA_REPLACE) || defined(RLUA_INTERNAL)

#define luaL_Buffer rluaL_Buffer
#define luaL_Reg rluaL_Reg
#define luaL_Stream rluaL_Stream
#define luaL_addgsub rluaL_addgsub
#define luaL_addlstring rluaL_addlstring    
#define luaL_addstring rluaL_addstring      
#define luaL_addvalue rluaL_addvalue        
#define luaL_argerror rluaL_argerror        
#define luaL_buffinit rluaL_buffinit        
#define luaL_buffinitsize rluaL_buffinitsize
#define luaL_callmeta rluaL_callmeta        
#define luaL_checkany rluaL_checkany        
#define luaL_checkinteger rluaL_checkinteger
#define luaL_checklstring rluaL_checklstring
#define luaL_checknumber rluaL_checknumber  
#define luaL_checkoption rluaL_checkoption  
#define luaL_checkstack rluaL_checkstack    
#define luaL_checktype rluaL_checktype      
#define luaL_checkudata rluaL_checkudata
#define luaL_checkversion_ rluaL_checkversion_
#define luaL_error rluaL_error
#define luaL_execresult rluaL_execresult
#define luaL_fileresult rluaL_fileresult
#define luaL_getmetafield rluaL_getmetafield
#define luaL_getsubtable rluaL_getsubtable
#define luaL_gsub rluaL_gsub
#define luaL_len rluaL_len
#define luaL_loadbufferx rluaL_loadbufferx
#define luaL_loadfilex rluaL_loadfilex
#define luaL_loadstring rluaL_loadstring
#define luaL_newmetatable rluaL_newmetatable
#define luaL_newstate rluaL_newstate
#define luaL_openlibs rluaL_openlibs
#define luaL_optinteger rluaL_optinteger
#define luaL_optlstring rluaL_optlstring
#define luaL_optnumber rluaL_optnumber
#define luaL_prepbuffsize rluaL_prepbuffsize
#define luaL_pushresult rluaL_pushresult
#define luaL_pushresultsize rluaL_pushresultsize
#define luaL_ref rluaL_ref
#define luaL_requiref rluaL_requiref
#define luaL_setfuncs rluaL_setfuncs
#define luaL_setmetatable rluaL_setmetatable
#define luaL_testudata rluaL_testudata
#define luaL_tolstring rluaL_tolstring
#define luaL_traceback rluaL_traceback
#define luaL_typeerror rluaL_typeerror
#define luaL_unref rluaL_unref
#define luaL_where rluaL_where
#define lua_Alloc rlua_Alloc
#define lua_CFunction rlua_CFunction
#define lua_Debug rlua_Debug
#define lua_Hook rlua_Hook
#define lua_Integer rlua_Integer
#define lua_KContext rlua_KContext
#define lua_KFunction rlua_KFunction
#define lua_Number rlua_Number
#define lua_Reader rlua_Reader
#define lua_State rlua_State
#define lua_Unsigned rlua_Unsigned
#define lua_WarnFunction rlua_WarnFunction
#define lua_Writer rlua_Writer
#define lua_absindex rlua_absindex
#define lua_arith rlua_arith
#define lua_atpanic rlua_atpanic
#define lua_callk rlua_callk
#define lua_checkstack rlua_checkstack
#define lua_close rlua_close
#define lua_compare rlua_compare
#define lua_concat rlua_concat
#define lua_copy rlua_copy
#define lua_createtable rlua_createtable
#define lua_dump rlua_dump
#define lua_error rlua_error
#define lua_gc rlua_gc
#define lua_getallocf rlua_getallocf
#define lua_getfield rlua_getfield
#define lua_getglobal rlua_getglobal
#define lua_gethook rlua_gethook
#define lua_gethookcount rlua_gethookcount
#define lua_gethookmask rlua_gethookmask
#define lua_geti rlua_geti
#define lua_getinfo rlua_getinfo
#define lua_getiuservalue rlua_getiuservalue
#define lua_getlocal rlua_getlocal
#define lua_getmetatable rlua_getmetatable
#define lua_getstack rlua_getstack
#define lua_gettable rlua_gettable
#define lua_gettop rlua_gettop
#define lua_getupvalue rlua_getupvalue
#define lua_ident rlua_ident
#define lua_iscfunction rlua_iscfunction
#define lua_isinteger rlua_isinteger
#define lua_isnumber rlua_isnumber
#define lua_isstring rlua_isstring
#define lua_isuserdata rlua_isuserdata
#define lua_isyieldable rlua_isyieldable
#define lua_len rlua_len
#define lua_load rlua_load
#define lua_newstate rlua_newstate
#define lua_newthread rlua_newthread
#define lua_newuserdatauv rlua_newuserdatauv
#define lua_next rlua_next
#define lua_pcallk rlua_pcallk
#define lua_pushboolean rlua_pushboolean
#define lua_pushcclosure rlua_pushcclosure
#define lua_pushfstring rlua_pushfstring
#define lua_pushinteger rlua_pushinteger
#define lua_pushlightuserdata rlua_pushlightuserdata
#define lua_pushlstring rlua_pushlstring
#define lua_pushnil rlua_pushnil
#define lua_pushnumber rlua_pushnumber
#define lua_pushstring rlua_pushstring
#define lua_pushthread rlua_pushthread
#define lua_pushvalue rlua_pushvalue
#define lua_pushvfstring rlua_pushvfstring
#define lua_rawequal rlua_rawequal
#define lua_rawget rlua_rawget
#define lua_rawgeti rlua_rawgeti
#define lua_rawgetp rlua_rawgetp
#define lua_rawlen rlua_rawlen
#define lua_rawset rlua_rawset
#define lua_rawseti rlua_rawseti
#define lua_rawsetp rlua_rawsetp
#define lua_resetthread rlua_resetthread
#define lua_resume rlua_resume
#define lua_rotate rlua_rotate
#define lua_setallocf rlua_setallocf
#define lua_setfield rlua_setfield
#define lua_setglobal rlua_setglobal
#define lua_sethook rlua_sethook
#define lua_seti rlua_seti
#define lua_setiuservalue rlua_setiuservalue
#define lua_setlocal rlua_setlocal
#define lua_setmetatable rlua_setmetatable
#define lua_settable rlua_settable
#define lua_settop rlua_settop
#define lua_setupvalue rlua_setupvalue
#define lua_setwarnf rlua_setwarnf
#define lua_status rlua_status
#define lua_stringtonumber rlua_stringtonumber
#define lua_toboolean rlua_toboolean
#define lua_tocfunction rlua_tocfunction
#define lua_toclose rlua_toclose
#define lua_tointegerx rlua_tointegerx
#define lua_tolstring rlua_tolstring
#define lua_tonumberx rlua_tonumberx
#define lua_topointer rlua_topointer
#define lua_tothread rlua_tothread
#define lua_touserdata rlua_touserdata
#define lua_type rlua_type
#define lua_typename rlua_typename
#define lua_upvalueid rlua_upvalueid
#define lua_upvaluejoin rlua_upvaluejoin
#define lua_version rlua_version
#define lua_warning rlua_warning
#define lua_xmove rlua_xmove
#define lua_yieldk rlua_yieldk
#define luaopen_base rluaopen_base
#define luaopen_coroutine rluaopen_coroutine
#define luaopen_debug rluaopen_debug
#define luaopen_io rluaopen_io
#define luaopen_math rluaopen_math
#define luaopen_os rluaopen_os
#define luaopen_package rluaopen_package
#define luaopen_string rluaopen_string
#define luaopen_table rluaopen_table
#define luaopen_utf8 rluaopen_utf8

#if DBG_LUA_VERSION == 501
#if defined(RLUA_REPLACE)
#define lua_tonumber(L,i) rlua_tonumberx(L,(i),NULL)
#define lua_tointeger(L,i) rlua_tointegerx(L,(i),NULL)
#define lua_call(L,n,r) rlua_callk(L, (n), (r), 0, NULL)
#define lua_pcall(L,n,r,f) rlua_pcallk(L, (n), (r), (f), 0, NULL)
#define luaL_loadbuffer(L,s,sz,n) rluaL_loadbufferx(L,s,sz,n,NULL)
#endif
#endif

#endif

#else

#include <lua.hpp>

#define rluaL_Buffer luaL_Buffer
#define rluaL_Reg luaL_Reg
#define rluaL_Stream luaL_Stream
#define rluaL_addchar luaL_addchar
#define rluaL_addgsub luaL_addgsub
#define rluaL_addlstring luaL_addlstring
#define rluaL_addsize luaL_addsize
#define rluaL_addstring luaL_addstring
#define rluaL_addvalue luaL_addvalue
#define rluaL_argcheck luaL_argcheck
#define rluaL_argerror luaL_argerror
#define rluaL_argexpected luaL_argexpected
#define rluaL_buffaddr luaL_buffaddr
#define rluaL_buffinit luaL_buffinit
#define rluaL_buffinitsize luaL_buffinitsize
#define rluaL_bufflen luaL_bufflen
#define rluaL_callmeta luaL_callmeta
#define rluaL_checkany luaL_checkany
#define rluaL_checkint luaL_checkint
#define rluaL_checkinteger luaL_checkinteger
#define rluaL_checklong luaL_checklong
#define rluaL_checklstring luaL_checklstring
#define rluaL_checknumber luaL_checknumber
#define rluaL_checkoption luaL_checkoption
#define rluaL_checkstack luaL_checkstack
#define rluaL_checkstring luaL_checkstring
#define rluaL_checktype luaL_checktype
#define rluaL_checkudata luaL_checkudata
#define rluaL_checkunsigned luaL_checkunsigned
#define rluaL_checkversion luaL_checkversion
#define rluaL_checkversion_ luaL_checkversion_
#define rluaL_dofile luaL_dofile
#define rluaL_dostring luaL_dostring
#define rluaL_error luaL_error
#define rluaL_execresult luaL_execresult
#define rluaL_fileresult luaL_fileresult
#define rluaL_getmetafield luaL_getmetafield
#define rluaL_getmetatable luaL_getmetatable
#define rluaL_getsubtable luaL_getsubtable
#define rluaL_gsub luaL_gsub
#define rluaL_len luaL_len
#define rluaL_loadbuffer luaL_loadbuffer
#define rluaL_loadbufferx luaL_loadbufferx
#define rluaL_loadfile luaL_loadfile
#define rluaL_loadfilex luaL_loadfilex
#define rluaL_loadstring luaL_loadstring
#define rluaL_newlib luaL_newlib
#define rluaL_newlibtable luaL_newlibtable
#define rluaL_newmetatable luaL_newmetatable
#define rluaL_newstate luaL_newstate
#define rluaL_openlibs luaL_openlibs
#define rluaL_opt luaL_opt
#define rluaL_optint luaL_optint
#define rluaL_optinteger luaL_optinteger
#define rluaL_optlong luaL_optlong
#define rluaL_optlstring luaL_optlstring
#define rluaL_optnumber luaL_optnumber
#define rluaL_optstring luaL_optstring
#define rluaL_optunsigned luaL_optunsigned
#define rluaL_prepbuffer luaL_prepbuffer
#define rluaL_prepbuffsize luaL_prepbuffsize
#define rluaL_pushresult luaL_pushresult
#define rluaL_pushresultsize luaL_pushresultsize
#define rluaL_ref luaL_ref
#define rluaL_requiref luaL_requiref
#define rluaL_setfuncs luaL_setfuncs
#define rluaL_setmetatable luaL_setmetatable
#define rluaL_testudata luaL_testudata
#define rluaL_tolstring luaL_tolstring
#define rluaL_traceback luaL_traceback
#define rluaL_typeerror luaL_typeerror
#define rluaL_typename luaL_typename
#define rluaL_unref luaL_unref
#define rluaL_where luaL_where
#define rlua_Alloc lua_Alloc
#define rlua_CFunction lua_CFunction
#define rlua_Debug lua_Debug
#define rlua_Hook lua_Hook
#define rlua_Integer lua_Integer
#define rlua_KContext lua_KContext
#define rlua_KFunction lua_KFunction
#define rlua_Number lua_Number
#define rlua_Reader lua_Reader
#define rlua_State lua_State
#define rlua_Unsigned lua_Unsigned
#define rlua_WarnFunction lua_WarnFunction
#define rlua_Writer lua_Writer
#define rlua_absindex lua_absindex
#define rlua_arith lua_arith
#define rlua_assert lua_assert
#define rlua_atpanic lua_atpanic
#define rlua_call lua_call
#define rlua_callk lua_callk
#define rlua_checkstack lua_checkstack
#define rlua_close lua_close
#define rlua_compare lua_compare
#define rlua_concat lua_concat
#define rlua_copy lua_copy
#define rlua_createtable lua_createtable
#define rlua_dump lua_dump
#define rlua_error lua_error
#define rlua_gc lua_gc
#define rlua_getallocf lua_getallocf
#define rlua_getextraspace lua_getextraspace
#define rlua_getfield lua_getfield
#define rlua_getglobal lua_getglobal
#define rlua_gethook lua_gethook
#define rlua_gethookcount lua_gethookcount
#define rlua_gethookmask lua_gethookmask
#define rlua_geti lua_geti
#define rlua_getinfo lua_getinfo
#define rlua_getiuservalue lua_getiuservalue
#define rlua_getlocal lua_getlocal
#define rlua_getmetatable lua_getmetatable
#define rlua_getstack lua_getstack
#define rlua_gettable lua_gettable
#define rlua_gettop lua_gettop
#define rlua_getupvalue lua_getupvalue
#define rlua_getuservalue lua_getuservalue
#define rlua_h lua_h
#define rlua_ident lua_ident
#define rlua_insert lua_insert
#define rlua_isboolean lua_isboolean
#define rlua_iscfunction lua_iscfunction
#define rlua_isfunction lua_isfunction
#define rlua_isinteger lua_isinteger
#define rlua_islightuserdata lua_islightuserdata
#define rlua_isnil lua_isnil
#define rlua_isnone lua_isnone
#define rlua_isnoneornil lua_isnoneornil
#define rlua_isnumber lua_isnumber
#define rlua_isstring lua_isstring
#define rlua_istable lua_istable
#define rlua_isthread lua_isthread
#define rlua_isuserdata lua_isuserdata
#define rlua_isyieldable lua_isyieldable
#define rlua_len lua_len
#define rlua_load lua_load
#define rlua_newstate lua_newstate
#define rlua_newtable lua_newtable
#define rlua_newthread lua_newthread
#define rlua_newuserdata lua_newuserdata
#define rlua_newuserdatauv lua_newuserdatauv
#define rlua_next lua_next
#define rlua_pcall lua_pcall
#define rlua_pcallk lua_pcallk
#define rlua_pop lua_pop
#define rlua_pushboolean lua_pushboolean
#define rlua_pushcclosure lua_pushcclosure
#define rlua_pushcfunction lua_pushcfunction
#define rlua_pushfstring lua_pushfstring
#define rlua_pushglobaltable lua_pushglobaltable
#define rlua_pushinteger lua_pushinteger
#define rlua_pushlightuserdata lua_pushlightuserdata
#define rlua_pushliteral lua_pushliteral
#define rlua_pushlstring lua_pushlstring
#define rlua_pushnil lua_pushnil
#define rlua_pushnumber lua_pushnumber
#define rlua_pushstring lua_pushstring
#define rlua_pushthread lua_pushthread
#define rlua_pushunsigned lua_pushunsigned
#define rlua_pushvalue lua_pushvalue
#define rlua_pushvfstring lua_pushvfstring
#define rlua_rawequal lua_rawequal
#define rlua_rawget lua_rawget
#define rlua_rawgeti lua_rawgeti
#define rlua_rawgetp lua_rawgetp
#define rlua_rawlen lua_rawlen
#define rlua_rawset lua_rawset
#define rlua_rawseti lua_rawseti
#define rlua_rawsetp lua_rawsetp
#define rlua_register lua_register
#define rlua_remove lua_remove
#define rlua_replace lua_replace
#define rlua_resetthread lua_resetthread
#define rlua_resume lua_resume
#define rlua_rotate lua_rotate
#define rlua_setallocf lua_setallocf
#define rlua_setfield lua_setfield
#define rlua_setglobal lua_setglobal
#define rlua_sethook lua_sethook
#define rlua_seti lua_seti
#define rlua_setiuservalue lua_setiuservalue
#define rlua_setlocal lua_setlocal
#define rlua_setmetatable lua_setmetatable
#define rlua_settable lua_settable
#define rlua_settop lua_settop
#define rlua_setupvalue lua_setupvalue
#define rlua_setuservalue lua_setuservalue
#define rlua_setwarnf lua_setwarnf
#define rlua_status lua_status
#define rlua_stringtonumber lua_stringtonumber
#define rlua_toboolean lua_toboolean
#define rlua_tocfunction lua_tocfunction
#define rlua_toclose lua_toclose
#define rlua_tointeger lua_tointeger
#define rlua_tointegerx lua_tointegerx
#define rlua_tolstring lua_tolstring
#define rlua_tonumber lua_tonumber
#define rlua_tonumberx lua_tonumberx
#define rlua_topointer lua_topointer
#define rlua_tostring lua_tostring
#define rlua_tothread lua_tothread
#define rlua_tounsigned lua_tounsigned
#define rlua_tounsignedx lua_tounsignedx
#define rlua_touserdata lua_touserdata
#define rlua_type lua_type
#define rlua_typename lua_typename
#define rlua_upvalueid lua_upvalueid
#define rlua_upvalueindex lua_upvalueindex
#define rlua_upvaluejoin lua_upvaluejoin
#define rlua_version lua_version
#define rlua_warning lua_warning
#define rlua_writeline lua_writeline
#define rlua_writestring lua_writestring
#define rlua_writestringerror lua_writestringerror
#define rlua_xmove lua_xmove
#define rlua_yield lua_yield
#define rlua_yieldk lua_yieldk
#define rluaopen_base luaopen_base
#define rluaopen_coroutine luaopen_coroutine
#define rluaopen_debug luaopen_debug
#define rluaopen_io luaopen_io
#define rluaopen_math luaopen_math
#define rluaopen_os luaopen_os
#define rluaopen_package luaopen_package
#define rluaopen_string luaopen_string
#define rluaopen_table luaopen_table
#define rluaopen_utf8 luaopen_utf8

#define RLUA_REGISTRYINDEX LUA_REGISTRYINDEX

#include "lua_compat.h"

#endif


#if defined(_WIN32)
#define RLUA_FUNC extern "C" __declspec(dllexport)
#else
#define RLUA_FUNC extern "C" __attribute__((visibility("default"))) 
#endif

#if defined(RLUA_REPLACE)
#undef  LUA_REGISTRYINDEX
#define LUA_REGISTRYINDEX	(-1000000/* LUAI_MAXSTACK */ - 1000)
#endif
