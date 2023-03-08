#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}

#include <algorithm>
#include <math.h>

static_assert((offsetof(ecs::motion_sampler, source_r) - offsetof(ecs::motion_sampler, source_s)) == sizeof(math_t), "Invalid motion_sampler defined");
static_assert((offsetof(ecs::motion_sampler, source_t) - offsetof(ecs::motion_sampler, source_r)) == sizeof(math_t), "Invalid motion_sampler defined");

static_assert((offsetof(ecs::motion_sampler, target_r) - offsetof(ecs::motion_sampler, target_s)) == sizeof(math_t), "Invalid motion_sampler defined");
static_assert((offsetof(ecs::motion_sampler, target_t) - offsetof(ecs::motion_sampler, target_r)) == sizeof(math_t), "Invalid motion_sampler defined");


static_assert((offsetof(ecs::scene, r) - offsetof(ecs::scene, s)) == sizeof(math_t), "Invalid motion_sampler defined");
static_assert((offsetof(ecs::scene, t) - offsetof(ecs::scene, r)) == sizeof(math_t), "Invalid motion_sampler defined");

namespace {
	enum tween_type { None, Back, Bounce, Circular, Cubic, Elastic, Exponential, Linear, Quadratic, Quartic, Quintic, Sine };
	const float kPI = 3.141592f;
	inline float square(float t) {
		return t * t;
	}

	float back(float t) {
		return t * t * (2.70158f * t - 1.70158f);
	}

	float bounce(float t) {
		if (t > 1.f - 1.f / 2.75f)
			return 1.f - 7.5625f * square(1.f - t);
		else if (t > 1.f - 2.f / 2.75f)
			return 1.0f - (7.5625f * square(1.f - t - 1.5f / 2.75f) + 0.75f);
		else if (t > 1.f - 2.5f / 2.75f)
			return 1.0f - (7.5625f * square(1.f - t - 2.25f / 2.75f) + 0.9375f);
		return 1.0f - (7.5625f * square(1.f - t - 2.625f / 2.75f) + 0.984375f);
	}

	float circular(float t) {
		return 1.f - sqrtf(1.f - t * t);
	}

	float cubic(float t) {
		return t * t * t;
	}

	float elastic(float t) {
		if (t == 0) return t;
		if (t == 1) return t;
		return -expf(7.24f * (t - 1.f)) * sinf((t - 1.1f) * 2.f * kPI / 0.4f);
	}

	float exponential(float t) {
		if (t == 0) return t;
		if (t == 1) return t;
		return expf(7.24f * (t - 1.f));
	}

	float linear(float t) {
		return t;
	}

	float quadratic(float t) {
		return t * t;
	}

	float quartic(float t) {
		return t * t * t * t;
	}

	float quintic(float t) {
		return t * t * t * t * t;
	}

	float sine(float t) {
		return 1.f - cosf(t * kPI * 0.5f);
	}

	float do_tween(tween_type type, float t) {
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

	float tween_in(tween_type type_in, float t) {
		return do_tween(type_in, t);
	}

	float tween_out(tween_type type_out, float t) {
		return 1.0f - do_tween(type_out, 1.0f - t);
	}

	float tween_in_out(tween_type type_in, tween_type type_out, float t) {
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
}

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
			const float ratio = tween(std::min(1.f, ms.deltatime / ms.duration), (tween_type)ms.tween_in, (tween_type)ms.tween_out);
			auto update_m3d = [w](math_t& m, const math_t n){
				math_unmark(w->math3d->M, m);
				m = math_mark(w->math3d->M, n);
			};

			if (!math_isnull(ms.target_s)){
				update_m3d(scene.s, math3d_lerp(w->math3d->M, ms.source_s, ms.target_s, ratio));
			}

			if (!math_isnull(ms.target_r)){
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