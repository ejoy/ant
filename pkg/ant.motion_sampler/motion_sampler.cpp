#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#include <ranges>

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

	ecs_api::context ecs {w->ecs};
	int gids[] = {motion_groupid};
	ecs.group_enable<ecs::motion_sampler_tag>(gids);

	for (auto e : ecs.select<ecs::view_visible, ecs::motion_sampler_tag, ecs::motion_sampler, ecs::scene>()){
		const auto& ms = e.get<ecs::motion_sampler>();
		auto &scene = e.get<ecs::scene>();
		//interplate s/r/t
		const math_t* source_srt = &ms.source_s;
		const math_t* target_srt = &ms.target_s;
		math_t* scene_srt = &scene.s;

		for (int i=0; i<3; ++i){
			const math_t s = source_srt[i];
			const math_t d = target_srt[i];

			if (!math_isnull(d)){
				assert(math_isnull(s));

				auto &r = scene_srt[i];
				math_unmark(w->math3d->M, r);
				r = math_mark(w->math3d->M, math3d_lerp(w->math3d->M, s, d, ms.ratio));
			}
		}
	}
    return 1;
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