#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#include <algorithm>

static_assert((offsetof(ecs::motion_sampler, source_r) - offsetof(ecs::motion_sampler, source_s)) == sizeof(math_t), "Invalid motion_sampler defined");
static_assert((offsetof(ecs::motion_sampler, source_t) - offsetof(ecs::motion_sampler, source_r)) == sizeof(math_t), "Invalid motion_sampler defined");

static_assert((offsetof(ecs::motion_sampler, target_r) - offsetof(ecs::motion_sampler, target_s)) == sizeof(math_t), "Invalid motion_sampler defined");
static_assert((offsetof(ecs::motion_sampler, target_t) - offsetof(ecs::motion_sampler, target_r)) == sizeof(math_t), "Invalid motion_sampler defined");


static_assert((offsetof(ecs::scene, r) - offsetof(ecs::scene, s)) == sizeof(math_t), "Invalid motion_sampler defined");
static_assert((offsetof(ecs::scene, t) - offsetof(ecs::scene, r)) == sizeof(math_t), "Invalid motion_sampler defined");

static int
lsample(lua_State *L){
    auto w = getworld(L);
	const int motion_groupid = (int)luaL_checkinteger(L, 1);
	const float deltaMS = (float)luaL_checknumber(L, 2);

	int gids[] = {motion_groupid};
	ecs_api::group_enable<ecs::motion_sampler_tag>(w->ecs, gids);

	for (auto e : ecs_api::select<ecs::view_visible, ecs::motion_sampler_tag, ecs::motion_sampler, ecs::scene>(w->ecs)){
		auto& ms = e.get<ecs::motion_sampler>();
		auto &scene = e.get<ecs::scene>();

		if (ms.deltatime <= ms.duration){
			ms.deltatime += deltaMS;
			const float ratio = std::min(1.f, ms.deltatime / ms.duration);
			auto update_m3d = [w](math_t& m, const math_t n){
				math_unmark(w->math3d->M, m);
				m = math_mark(w->math3d->M, n);
			};

			if (!math_isnull(ms.target_s)){
				update_m3d(scene.s, math3d_lerp(w->math3d->M, ms.source_s, ms.target_s, ratio));
			}

			if (!math_isnull(ms.target_r)){
				const char* tt = math_typename(math_type(w->math3d->M, ms.target_r));
				const char* tt1= math_typename(math_type(w->math3d->M, ms.source_r));
				update_m3d(scene.r, math3d_quat_lerp(w->math3d->M, ms.source_r, ms.target_r, ratio));
			}

			if (!math_isnull(ms.target_t)){
				update_m3d(scene.t, math3d_lerp(w->math3d->M, ms.source_t, ms.target_t, ratio));
			}

			e.enable_tag<ecs::scene_needchange>();
		}
	}
    return 0;
}

extern "C" int
luaopen_motion_sampler(lua_State *L) {
    luaL_checkversion(L);
	luaL_Reg l[] = {
        { "sample", lsample},
		{ nullptr, nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
    return 1;
}