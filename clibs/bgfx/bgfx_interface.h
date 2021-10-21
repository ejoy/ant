#ifndef lua_bgfx_interface_h
#define lua_bgfx_interface_h

#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

#if defined(__cplusplus)
extern "C"
#else
extern
#endif
bgfx_interface_vtbl_t* bgfx_inf_;

#define BGFX(api) bgfx_inf_->api
#define BGFX_ENCODER(api, encoder, ...) (encoder ? (BGFX(encoder_##api)( encoder, ## __VA_ARGS__ )) : BGFX(api)( __VA_ARGS__ ))

#endif
