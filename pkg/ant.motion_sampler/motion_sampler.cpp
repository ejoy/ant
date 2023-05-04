#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

#include "ozz/animation/runtime/track_sampling_job.h"
#include "ozz/animation/offline/raw_track.h"
#include "ozz/animation/offline/track_builder.h"

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

struct motion_tracks {
	ozz::unique_ptr<ozz::animation::Float3Track>		s;
	ozz::unique_ptr<ozz::animation::QuaternionTrack>	r;
	ozz::unique_ptr<ozz::animation::Float3Track>		t;

	struct result {
		math_t s, r, t;
	};

	result res;
};

struct motion_keyframe {
	ozz::animation::offline::RawFloat3Track::Keyframe		s;
	ozz::animation::offline::RawQuaternionTrack::Keyframe	r;
	ozz::animation::offline::RawFloat3Track::Keyframe		t;
};


static inline void
sample_value(struct ecs_world* w, const ecs::motion_sampler &ms, float ratio, ecs::scene &scene){
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
}

static int
lsample(lua_State *L){
    auto w = getworld(L);
	const int motion_groupid = (int)luaL_checkinteger(L, 1);

	int gids[] = {motion_groupid};
	ecs_api::group_enable<ecs::motion_sampler_tag>(w->ecs, gids);

	for (auto e : ecs_api::select<ecs::view_visible, ecs::motion_sampler_tag, ecs::motion_sampler, ecs::scene>(w->ecs)){
		auto& ms = e.get<ecs::motion_sampler>();
		auto &scene = e.get<ecs::scene>();

		sample_value(w, ms, ms.ratio, scene);
	}
    return 0;
}

static inline motion_tracks*
MT(lua_State *L, int index = 1){
	return (motion_tracks*)luaL_checkudata(L, index, "TRACKS_MT");
}

static inline void
sampling_motion_tracks(motion_tracks *mt){

}

static int
ltracks_delete(lua_State *L){
	auto mt = MT(L);
	auto w = getworld(L);

	mt->s = nullptr;
	mt->r = nullptr;
	mt->t = nullptr;

	if (!math_isnull(mt->res.s)){
		math_unmark(w->math3d->M, mt->res.s);
		mt->res.s = MATH_NULL;
	}

	if (!math_isnull(mt->res.r)){
		math_unmark(w->math3d->M, mt->res.r);
		mt->res.r = MATH_NULL;
	}

	if (!math_isnull(mt->res.t)){
		math_unmark(w->math3d->M, mt->res.t);
		mt->res.t = MATH_NULL;
	}
	return 0;
}

static inline void
extract_keyframe(lua_State *L, int index, ecs_world* w, motion_keyframe &kf){
	luaL_checktype(L, index, LUA_TTABLE);

	//step
	const int steptype = lua_getfield(L, index, "step");
	if (steptype != LUA_TNUMBER){
		luaL_error(L, "Need step in keyframe table");
	}
	const float step = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);

	const auto M = w->math3d->M;
	// s
	const int st = lua_getfield(L, index, "s");
	if (st != LUA_TNIL){
		const math_t s = {(size_t)lua_touserdata(L, -1)};	//math_t type
		if (!math_valid(M, s)){
			luaL_error(L, "Invalid 's' data: %d", index);
		}

		const float *sv = math_value(M, s);
		kf.s = ozz::animation::offline::RawFloat3Track::Keyframe {
			ozz::animation::offline::RawTrackInterpolation::kLinear, step,
			ozz::math::Float3(sv[0], sv[1], sv[2])
		};
	}
	lua_pop(L, 1);

	// r
	const int rt = lua_getfield(L, index, "r");
	if (rt != LUA_TNIL){
		const math_t r = {(size_t)lua_touserdata(L, -1)};	//math_t type
		if (!math_valid(M, r)){
			luaL_error(L, "Invalid 'r' data: %d", index);
		}

		const float *rv = math_value(M, r);
		kf.r = ozz::animation::offline::RawQuaternionTrack::Keyframe {
			ozz::animation::offline::RawTrackInterpolation::kLinear, step,
			ozz::math::Quaternion(rv[0], rv[1], rv[2], rv[3])
		};
	}
	lua_pop(L, 1);

	// t
	const int tt = lua_getfield(L, index, "t");
	if (tt != LUA_TNIL){
		const math_t t = {(size_t)lua_touserdata(L, -1)};	//math_t type
		if (!math_valid(M, t)){
			luaL_error(L, "Invalid 't' data: %d", index);
		}

		const float *rv = math_value(M, t);
		kf.t = ozz::animation::offline::RawFloat3Track::Keyframe {
			ozz::animation::offline::RawTrackInterpolation::kLinear, step,
			ozz::math::Float3(rv[0], rv[1], rv[2])
		};
	}
	lua_pop(L, 1);
}

static int
ltracks_sample(lua_State *L){
	auto mt = MT(L);
	auto w = getworld(L);
	const float ratio = (float)luaL_checknumber(L, 2);
	const auto M = w->math3d->M;
	if (!mt->s->ratios().empty()){
		ozz::math::Float3 s;
		
		ozz::animation::Float3TrackSamplingJob job;
		job.track = mt->s.get();
		job.result = &s;
		job.ratio = ratio;

		math_unmark(M, mt->res.s);
		float v[] = {s.x, s.y, s.z, 0.0f};
		mt->res.s = math_mark(M, math_vec4(M, v));
	}

	if (!mt->r->ratios().empty()){
		ozz::math::Quaternion r;
		ozz::animation::QuaternionTrackSamplingJob job;
		job.track = mt->r.get();
		job.result = &r;
		job.ratio = ratio;

		math_unmark(M, mt->res.r);
		mt->res.r = math_mark(M, math_quat(M, &r.x));
	}

	if (!mt->t->ratios().empty()){
		ozz::math::Float3 t;
		ozz::animation::Float3TrackSamplingJob job;
		job.track = mt->t.get();
		job.result = &t;
		job.ratio = ratio;

		float v[] = {t.x, t.y, t.z, 1.0f};
		math_unmark(M, mt->res.t);
		mt->res.t = math_mark(M, math_vec4(M, v));
	}

	ozz::animation::QuaternionTrackSamplingJob r_job;
	ozz::animation::Float3TrackSamplingJob t_job;

	return 0;
}

static int
lcreate_tracks(lua_State *L){
	const int n = lua_gettop(L);
	auto mt = (motion_tracks*)lua_newuserdatauv(L, sizeof(motion_tracks), 0);
	new (mt) motion_tracks();

	auto w = getworld(L);
	if (n > 0){
		motion_keyframe kf;
		ozz::animation::offline::RawFloat3Track s_tracks, t_tracks;
		ozz::animation::offline::RawQuaternionTrack r_tracks;
		for (int i=1; i<=n; ++i){
			extract_keyframe(L, i, w, kf);
			s_tracks.keyframes.push_back(kf.s);
			r_tracks.keyframes.push_back(kf.r);
			t_tracks.keyframes.push_back(kf.t);
		}
		ozz::animation::offline::TrackBuilder builder;
		mt->s = builder(s_tracks);
		mt->r = builder(r_tracks);
		mt->t = builder(t_tracks);
	}

	mt->res.s = math_mark(w->math3d->M, math_identity(MATH_TYPE_VEC4));
	mt->res.r = math_mark(w->math3d->M, math_identity(MATH_TYPE_QUAT));
	mt->res.t = math_mark(w->math3d->M, math_identity(MATH_TYPE_VEC4));

	if (luaL_newmetatable(L, "TRACKS_MT")){
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
		luaL_Reg l[] = {
			{ "sample",		ltracks_sample},
			{ "__gc",		ltracks_delete},
			{ nullptr, 		nullptr},
		};
		luaL_setfuncs(L, l, 0);
	}

	lua_setmetatable(L, -2);
	return 1;
}

extern "C" int
luaopen_motion_sampler(lua_State *L) {
    luaL_checkversion(L);
	luaL_Reg l[] = {
        { "sample",			lsample},
		{ "create_tracks",	lcreate_tracks},
		{ nullptr,			nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
    return 1;
}
