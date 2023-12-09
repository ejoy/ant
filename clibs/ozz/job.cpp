#include <lua.hpp>
#include <bee/lua/binding.h>

#include "ozz.h"

#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>


static int SamplingJob(lua_State* L) {
    auto& animation = bee::lua::checkudata<ozzAnimation>(L, 1);
    auto& locals = bee::lua::checkudata<ozzSoaTransformVector>(L, 2);
    float ratio = (float)luaL_checknumber(L, 3);
    ozz::animation::SamplingJob job;
    job.animation = animation.v;
    job.context = animation.sampling_context;
    job.ratio = ratio;
    job.output = ozz::make_span(locals);
    if (!job.Run()) {
    	return luaL_error(L, "SamplingJob failed!");
    }
    return 0;
}

static int LocalToModelJob(lua_State* L) {
    ozz::animation::LocalToModelJob job;
    auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
    job.skeleton = ske.v;
    if (lua_type(L, 2) == LUA_TNIL) {
        job.input = ske.v->joint_rest_poses();
    }
    else {
        job.input = ozz::make_span(bee::lua::checkudata<ozzSoaTransformVector>(L, 2));
    }
    job.output = ozz::make_span(bee::lua::checkudata<ozzMatrixVector>(L, 3));
    if (lua_isnoneornil(L, 4)) {
        job.root = (ozz::math::Float4x4*)lua_touserdata(L, 4);
    }
    if (!job.Run()) {
        return luaL_error(L, "LocalToModelJob failed!");
    }
    return 0;
}

void init_job(lua_State* L) {
    static luaL_Reg lib[] = {
        { "SamplingJob", SamplingJob },
        { "LocalToModelJob", LocalToModelJob },
        { NULL, NULL },
    };
    luaL_setfuncs(L, lib, 0);
}
