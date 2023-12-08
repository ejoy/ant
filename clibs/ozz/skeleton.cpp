#include <lua.hpp>
#include <binding/binding.h>

#include "ozz.h"

#include <ozz/base/io/archive.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/maths/soa_float4x4.h>

#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/skeleton_utils.h>

#define REGISTER_LUA_NAME(C) namespace bee::lua { template <> struct udata<C> { static inline auto name = #C; }; }
REGISTER_LUA_NAME(ozzSkeleton)
#undef REGISTER_LUA_NAME

namespace ozzlua::Skeleton {
    static int find_joint_index(const ozz::animation::Skeleton *ske, const char*name) {
        const auto& joint_names = ske->joint_names();
        for (int ii = 0; ii < (int)joint_names.size(); ++ii) {
            if (strcmp(name, joint_names[ii]) == 0) {
                return ii;
            }
        }

        return -1;
    }

    static inline int get_joint_index(lua_State* L, const ozz::animation::Skeleton *ske, int index) {
        int type = lua_type(L, 2);
        int jointidx = -1;
        if (type == LUA_TNUMBER) {
            jointidx = (int)lua_tointeger(L, 2) - 1;
        } else {
            luaL_error(L, "only support integer[joint index] or string[joint name], type : %d", type);
            return -1;
        }

        if (jointidx < 0 || jointidx >= (int)ske->num_joints()) {
            luaL_error(L, "invalid joint index : %d", jointidx);
            return -1;
        }
        return jointidx;
    }

    static int serialize(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        //TODO: implement a custom stream can remove one more memory copy
        ozz::io::MemoryStream ms;
        ozz::io::OArchive oa(&ms);
        oa << *ske.v;
        ozz::io::IArchive ia(&ms);
        std::string s; s.resize(ms.Size());
        ia.LoadBinary(s.data(), s.size());
        lua_pushlstring(L, s.data(), s.size());
        return 1;
    }

    static int isleaf(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        auto jointidx = get_joint_index(L, ske.v, 2);
        lua_pushboolean(L, ozz::animation::IsLeaf(*ske.v, jointidx));
        return 1;
    }

    static int parent(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske.v, 2);
        auto parents = ske.v->joint_parents();
        auto parentid = parents[jointidx];
        lua_pushinteger(L, parentid + 1);
        return 1;
    }

    static int isroot(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske.v, 2);
        auto parents = ske.v->joint_parents();
        auto parentid = parents[jointidx];
        lua_pushboolean(L, parentid == ozz::animation::Skeleton::kNoParent);
        return 1;
    }

    static int jointindex(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        const char* name = luaL_checkstring(L, 2);
        auto jointidx = find_joint_index(ske.v, name);
        if (jointidx >= 0) {
            lua_pushinteger(L, jointidx + 1);
            return 1;
        }
        return 0;
    }

    static ozz::math::Float4x4 joint_matrix(const ozz::animation::Skeleton *ske, int jointidx) {
        auto poses = ske->joint_rest_poses();
        assert(0 <= jointidx && jointidx < ske->num_joints());
        auto pose = poses[jointidx / 4];
        auto subidx = jointidx % 4;
        const ozz::math::SoaFloat4x4 local_soa_matrices = ozz::math::SoaFloat4x4::FromAffine(pose.translation, pose.rotation, pose.scale);
        // Converts to aos matrices.
        ozz::math::Float4x4 local_aos_matrices[4];
        ozz::math::Transpose16x16(&local_soa_matrices.cols[0].x, local_aos_matrices->cols);
        return local_aos_matrices[subidx];
    }

    static int joint(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske.v, 2);
        auto *r = (float*)lua_touserdata(L, 3);
        const auto trans = joint_matrix(ske.v, jointidx);
        assert(sizeof(trans) <= sizeof(float) * 16);
        memcpy(r, &trans, sizeof(trans));
        return 0;
    }

    static int jointname(lua_State* L){
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske.v, 2);
        auto name = ske.v->joint_names()[jointidx];
        lua_pushstring(L, name);
        return 1;
    }

    static int bindpose(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        auto& pr = bee::lua::checkudata<ozzPoseResult>(L, 2);
        ozz::animation::LocalToModelJob job;
        job.skeleton = ske.v;
        job.input = ske.v->joint_rest_poses();
        job.output = ozz::make_span(pr);
        if (!job.Run()) {
            luaL_error(L, "build local to model failed");
        }
        return 0;
    }

    static int size(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        size_t buffersize = 0;
        auto bind_poses = ske.v->joint_rest_poses();
        buffersize += bind_poses.size_bytes();
        buffersize += ske.v->joint_parents().size() * sizeof(uint16_t);
        auto names = ske.v->joint_names();
        for (size_t ii = 0; ii < names.size(); ++ii){
            buffersize += strlen(names[ii]);
        }
        lua_pushinteger(L, buffersize);
        return 1;
    }

    static int __len(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozzSkeleton>(L, 1);
        lua_pushinteger(L, ske.v->num_joints());
        return 1;
    }

    static void metatable(lua_State* L) {
        static luaL_Reg lib[] = {
            { "serialize", serialize },
            { "isleaf", isleaf },
            { "parent", parent },
            { "isroot", isroot },
            { "joint_index", jointindex },
            { "joint", joint },
            { "joint_name", jointname },
            { "bind_pose", bindpose },
            { "size", size },
            { nullptr, nullptr }
        };
        luaL_newlib(L, lib);
        lua_setfield(L, -2, "__index");
        lua_pushcfunction(L, __len);
        lua_setfield(L, -2, "__len");
    }
    static int getmetatable(lua_State* L) {
        bee::lua::getmetatable<ozzSkeleton>(L, metatable);
        return 1;
    }
    static int create(lua_State* L, ozz::animation::Skeleton* v) {
        bee::lua::newudata<ozzSkeleton>(L, metatable, v);
        return 1;
    }
    const char* load(lua_State* L, ozz::io::IArchive& ia) {
        if (!ia.TestTag<ozz::animation::Skeleton>()) {
            return nullptr;
        }
        auto v = ozz::New<ozz::animation::Skeleton>();
        ia >> *v;
        create(L, v);
        return ozz::io::internal::Tag<const ozz::animation::Skeleton>::Get();
    }
}

void init_skeleton(lua_State* L) {
    luaL_Reg l[] = {
        { "skeleton_mt", ozzlua::Skeleton::getmetatable},
        { NULL, NULL },
    };
    luaL_setfuncs(L,l,0);
}
