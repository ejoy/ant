#include <lua.hpp>
#include <bee/lua/udata.h>

#include "ozz.h"

#include <ozz/base/io/archive.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/maths/soa_float4x4.h>

#include <cstring>

namespace ozzlua::Skeleton {
    static int find_joint_index(const ozz::animation::Skeleton& ske, const char*name) {
        const auto& joint_names = ske.joint_names();
        for (int ii = 0; ii < (int)joint_names.size(); ++ii) {
            if (strcmp(name, joint_names[ii]) == 0) {
                return ii;
            }
        }

        return -1;
    }

    static inline int get_joint_index(lua_State* L, const ozz::animation::Skeleton& ske, int index) {
        int jointidx = (int)luaL_checkinteger(L, 2) - 1;
        if (jointidx < 0 || jointidx >= (int)ske.num_joints()) {
            luaL_error(L, "invalid joint index : %d", jointidx);
            return -1;
        }
        return jointidx;
    }

    static int parent(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske, 2);
        auto parents = ske.joint_parents();
        auto parentid = parents[jointidx];
        lua_pushinteger(L, parentid + 1);
        return 1;
    }

    static int isroot(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske, 2);
        auto parents = ske.joint_parents();
        auto parentid = parents[jointidx];
        lua_pushboolean(L, parentid == ozz::animation::Skeleton::kNoParent);
        return 1;
    }

    static int jointindex(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        const char* name = luaL_checkstring(L, 2);
        auto jointidx = find_joint_index(ske, name);
        if (jointidx >= 0) {
            lua_pushinteger(L, jointidx + 1);
            return 1;
        }
        return 0;
    }

    static ozz::math::Float4x4 joint_matrix(const ozz::animation::Skeleton& ske, int jointidx) {
        auto poses = ske.joint_rest_poses();
        assert(0 <= jointidx && jointidx < ske.num_joints());
        auto pose = poses[jointidx / 4];
        auto subidx = jointidx % 4;
        const ozz::math::SoaFloat4x4 local_soa_matrices = ozz::math::SoaFloat4x4::FromAffine(pose.translation, pose.rotation, pose.scale);
        // Converts to aos matrices.
        ozz::math::Float4x4 local_aos_matrices[4];
        ozz::math::Transpose16x16(&local_soa_matrices.cols[0].x, local_aos_matrices->cols);
        return local_aos_matrices[subidx];
    }

    static int joint(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske, 2);
        auto *r = (float*)lua_touserdata(L, 3);
        const auto trans = joint_matrix(ske, jointidx);
        assert(sizeof(trans) <= sizeof(float) * 16);
        memcpy(r, &trans, sizeof(trans));
        return 0;
    }

    static int jointname(lua_State* L){
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        const int jointidx = get_joint_index(L, ske, 2);
        auto name = ske.joint_names()[jointidx];
        lua_pushstring(L, name);
        return 1;
    }

    static int num_soa_joints(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        lua_pushinteger(L, ske.num_soa_joints());
        return 1;
    }

    static int num_joints(lua_State* L) {
        auto& ske = bee::lua::checkudata<ozz::animation::Skeleton>(L, 1);
        lua_pushinteger(L, ske.num_joints());
        return 1;
    }

    static void metatable(lua_State* L) {
        static luaL_Reg lib[] = {
            { "parent", parent },
            { "isroot", isroot },
            { "joint_index", jointindex },
            { "joint", joint },
            { "joint_name", jointname },
            { "num_soa_joints", num_soa_joints },
            { "num_joints", num_joints },
            { nullptr, nullptr }
        };
        luaL_newlib(L, lib);
        lua_setfield(L, -2, "__index");
    }
    static int getmetatable(lua_State* L) {
        bee::lua::getmetatable<ozz::animation::Skeleton>(L);
        return 1;
    }
    bool load(lua_State* L, ozz::io::IArchive& ia) {
        if (!ia.TestTag<ozz::animation::Skeleton>()) {
            return false;
        }
        auto& o = bee::lua::newudata<ozz::animation::Skeleton>(L);
        ia >> (ozz::animation::Skeleton&)o;
        return true;
    }
}

void init_skeleton(lua_State* L) {
    luaL_Reg l[] = {
        { "SkeletonMt", ozzlua::Skeleton::getmetatable },
        { NULL, NULL },
    };
    luaL_setfuncs(L,l,0);
}

namespace bee::lua {
	template <>
	struct udata<ozz::animation::Skeleton> {
		static inline auto metatable = ozzlua::Skeleton::metatable;
	};
}
