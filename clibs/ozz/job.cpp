#include <lua.hpp>
#include <bee/lua/binding.h>
#include <bee/lua/udata.h>

#include "ozz.h"

#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>

namespace ozzlua::SamplingJobContext {
    static void metatable(lua_State* L) {
    }
    static int create(lua_State* L) {
        lua_Integer n = luaL_checkinteger(L, 1);
        bee::lua::newudata<ozz::animation::SamplingJob::Context>(L, (int)n);
        return 1;
    }
}

namespace ozzlua::BlendingJobLayerVector {
    static int resize(lua_State* L) {
        auto& vec = bee::lua::checkudata<ozzBlendingJobLayerVector>(L, 1);
        size_t n = bee::lua::checkinteger<size_t>(L, 2);
        vec.resize(n);
        return 0;
    }
    static int set(lua_State* L) {
        auto& vec = bee::lua::checkudata<ozzBlendingJobLayerVector>(L, 1);
        size_t n = bee::lua::checkinteger<size_t>(L, 2);
        if (!lua_isnoneornil(L, 3)) {
            auto& locals = bee::lua::checkudata<ozzSoaTransformVector>(L, 3);
            vec[n-1].transform = ozz::make_span(locals);
        }
        vec[n-1].weight = (float)luaL_optnumber(L, 4, 1.0);
        // TODO: joint_weights
        return 0;
    }
    static void metatable(lua_State* L) {
        static luaL_Reg lib[] = {
            { "resize", resize },
            { "set", set },
            { nullptr, nullptr }
        };
        luaL_newlibtable(L, lib);
        luaL_setfuncs(L, lib, 0);
        lua_setfield(L, -2, "__index");
    }
    static int create(lua_State* L) {
        bee::lua::newudata<ozzBlendingJobLayerVector>(L);
        return 1;
    }
}

static int SamplingJob(lua_State* L) {
    auto& animation = bee::lua::checkudata<ozz::animation::Animation>(L, 1);
    auto& context = bee::lua::checkudata<ozz::animation::SamplingJob::Context>(L, 2);
    auto& locals = bee::lua::checkudata<ozzSoaTransformVector>(L, 3);
    float ratio = (float)luaL_checknumber(L, 4);
    ozz::animation::SamplingJob job;
    job.animation = &animation;
    job.context = &context;
    job.ratio = ratio;
    job.output = ozz::make_span(locals);
    if (!job.Run()) {
        return luaL_error(L, "SamplingJob failed!");
    }
    return 0;
}

static int BlendingJob(lua_State* L) {
    ozz::animation::BlendingJob job;
    auto& layers = bee::lua::checkudata<ozzBlendingJobLayerVector>(L, 1);
    auto& locals = bee::lua::checkudata<ozzSoaTransformVector>(L, 2);
    auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 3);
    float threshold = (float)luaL_optnumber(L, 4, 0.1);
    if (!lua_isnoneornil(L, 5)) {
        auto& additive_layers = bee::lua::checkudata<ozzBlendingJobLayerVector>(L, 5);
        job.additive_layers =  ozz::make_span(additive_layers);
    }
    job.layers = ozz::make_span(layers);
    job.output = ozz::make_span(locals);
    job.threshold = threshold;
    job.rest_pose = ske.joint_rest_poses();
    if (!job.Run()) {
        return luaL_error(L, "BlendingJob failed!");
    }
    return 0;
}

static int LocalToModelJob(lua_State* L) {
    ozz::animation::LocalToModelJob job;
    auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
    job.skeleton = &ske;
    if (lua_type(L, 2) == LUA_TNIL) {
        job.input = ske.joint_rest_poses();
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
        { "SamplingJobContext", ozzlua::SamplingJobContext::create },
        { "BlendingJobLayerVector", ozzlua::BlendingJobLayerVector::create },
        { "SamplingJob", SamplingJob },
        { "BlendingJob", BlendingJob },
        { "LocalToModelJob", LocalToModelJob },
        { NULL, NULL },
    };
    luaL_setfuncs(L, lib, 0);
}

namespace bee::lua {
    template <>
    struct udata<ozz::animation::SamplingJob::Context> {
        static inline auto metatable = ozzlua::SamplingJobContext::metatable;
    };
    template <>
    struct udata<ozzBlendingJobLayerVector> {
        static inline auto metatable = ozzlua::BlendingJobLayerVector::metatable;
    };
}
