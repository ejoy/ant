#include "tween.h"

#include "lua.hpp"

#include <cmath>
#include <cstring>

const float kPI = 3.141592f;
static inline float square(float t) {
    return t * t;
}

static inline float back(float t) {
    return t * t * (2.70158f * t - 1.70158f);
}

static inline float bounce(float t) {
    if (t > 1.f - 1.f / 2.75f)
        return 1.f - 7.5625f * square(1.f - t);
    else if (t > 1.f - 2.f / 2.75f)
        return 1.0f - (7.5625f * square(1.f - t - 1.5f / 2.75f) + 0.75f);
    else if (t > 1.f - 2.5f / 2.75f)
        return 1.0f - (7.5625f * square(1.f - t - 2.25f / 2.75f) + 0.9375f);
    return 1.0f - (7.5625f * square(1.f - t - 2.625f / 2.75f) + 0.984375f);
}

static inline float circular(float t) {
    return 1.f - sqrtf(1.f - t * t);
}

static inline float cubic(float t) {
    return t * t * t;
}

static inline float elastic(float t) {
    if (t == 0) return t;
    if (t == 1) return t;
    return -expf(7.24f * (t - 1.f)) * sinf((t - 1.1f) * 2.f * kPI / 0.4f);
}

static inline float exponential(float t) {
    if (t == 0) return t;
    if (t == 1) return t;
    return expf(7.24f * (t - 1.f));
}

static inline float linear(float t) {
    return t;
}

static inline float quadratic(float t) {
    return t * t;
}

static inline float quartic(float t) {
    return t * t * t * t;
}

static inline float quintic(float t) {
    return t * t * t * t * t;
}

static inline float sine(float t) {
    return 1.f - cosf(t * kPI * 0.5f);
}

static inline float do_tween(tween_type type, float t) {
    switch (type) {
    case Back: return back(t);
    case Bounce: return bounce(t);
    case Circular: return circular(t);
    case Cubic: return cubic(t);
    case Elastic: return elastic(t);
    case Exponential: return exponential(t);
    case Linear: return linear(t);
    case Quadratic: return quadratic(t);
    case Quartic: return quartic(t);
    case Quintic: return quintic(t);
    case Sine: return sine(t);
    default:
        break;
    }
    return t;
}

static inline float tween_in(tween_type type_in, float t) {
    return do_tween(type_in, t);
}

static inline float tween_out(tween_type type_out, float t) {
    return 1.0f - do_tween(type_out, 1.0f - t);
}

static inline float tween_in_out(tween_type type_in, tween_type type_out, float t) {
    if (t < 0.5f)
        return do_tween(type_in, 2.0f * t) * 0.5f;
    else
        return 0.5f + tween_out(type_out, 2.0f * t - 1.0f) * 0.5f;
}

float tween(float t, tween_type type_in, tween_type type_out) {
    if (type_in != None && type_out == None) {
        return tween_in(type_in, t);
    }
    if (type_in == None && type_out != None) {
        return tween_out(type_out, t);
    }
    if (type_in != None && type_out != None) {
        return tween_in_out(type_in, type_out, t);
    }
    return t;
}

static int
ltween_type(lua_State *L){
    const char* tt = luaL_checkstring(L, 1);
    tween_type type = None;
    if (0 == strcmp(tt, "None")){
        type = None;
    } else if (0 == strcmp(tt, "Back")){
        type = Back;
    } else if (0 == strcmp(tt, "Bounce")){
        type = Bounce;
    } else if (0 == strcmp(tt, "Circular")){
        type = Circular;
    } else if (0 == strcmp(tt, "Cubic")){
        type = Cubic;
    } else if (0 == strcmp(tt, "Elastic")){
        type = Elastic;
    } else if (0 == strcmp(tt, "Exponential")){
        type = Exponential;
    } else if (0 == strcmp(tt, "Linear")){
        type = Linear;
    } else if (0 == strcmp(tt, "Quadratic")){
        type = Quadratic;
    } else if (0 == strcmp(tt, "Quartic")){
        type = Quartic;
    } else if (0 == strcmp(tt, "Quintic")){
        type = Quintic;
    } else if (0 == strcmp(tt, "Sine")){
        type = Sine;
    } else {
        luaL_error(L, "Unknown type:%s", tt);
    }

    lua_pushinteger(L, type);
    return 1;
}

static int
linterp(lua_State *L){
    const float t               = (float)luaL_checknumber(L, 1);
    const tween_type tween_in   = (tween_type)luaL_checkinteger(L, 2);
    const tween_type tween_out  = (tween_type)luaL_checkinteger(L, 3);
    
    const float ratio = tween(t, tween_in, tween_out);
    lua_pushnumber(L, ratio);
    return 1;
}

extern "C" int
luaopen_motion_tween(lua_State *L) {
    luaL_checkversion(L);
	luaL_Reg l[] = {
        { "interp",			linterp},
        { "type",           ltween_type},
		{ nullptr,			nullptr },
	};
	luaL_newlib(L, l);
    return 1;
}