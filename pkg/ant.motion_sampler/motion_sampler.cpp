#include "ecs/world.h"
#include "ecs/select.h"
#include "ecs/component.hpp"

#include "tween.h"
#include "mathid.h"

#include "ozz/animation/runtime/track_sampling_job.h"
#include "ozz/animation/offline/raw_track.h"
#include "ozz/animation/offline/track_builder.h"

extern "C"{
	#include "math3d.h"
	#include "math3dfunc.h"
}


struct motion_tracks {
	ozz::unique_ptr<ozz::animation::Float3Track>		s;
	ozz::unique_ptr<ozz::animation::QuaternionTrack>	r;
	ozz::unique_ptr<ozz::animation::Float3Track>		t;
};

struct motion_keyframe {
	ozz::animation::offline::RawFloat3Track::Keyframe		s;
	ozz::animation::offline::RawQuaternionTrack::Keyframe	r;
	ozz::animation::offline::RawFloat3Track::Keyframe		t;
};

static inline motion_keyframe
extract_keyframe(lua_State *L, int index, ecs_world* w){
	luaL_checktype(L, index, LUA_TTABLE);

	motion_keyframe kf;

	//step
	const int steptype = lua_getfield(L, index, "step");
	if (steptype != LUA_TNUMBER){
		luaL_error(L, "Need step in keyframe table");
	}
	const float step = (float)lua_tonumber(L, -1);
	lua_pop(L, 1);

	auto pull_keyframe = [L, w, step](int index, const char* name, auto& keyframe){
		const int st = lua_getfield(L, index, name);
		if (st != LUA_TNIL){
			const math_t s = math3d_from_lua_id(L, w->math3d, -1);
			if (!math_valid(w->math3d->M, s)){
				luaL_error(L, "Invalid '%s' data: %d", name, index);
			}

			const float *sv = math_value(w->math3d->M, s);
			keyframe.interpolation = ozz::animation::offline::RawTrackInterpolation::kLinear;
			keyframe.ratio = step;

			using ValueType = decltype(keyframe.value);
			keyframe.value = *((ValueType*)sv);
		} else {
			keyframe.ratio = -1.f;
		}
		lua_pop(L, 1);
	};

	pull_keyframe(index, "s", kf.s);
	pull_keyframe(index, "r", kf.r);
	pull_keyframe(index, "t", kf.t);

	return kf;
}

static inline void
build_tracks(lua_State *L, ecs_world *w, int index, motion_tracks *mt){
	luaL_checktype(L, index, LUA_TTABLE);
	const int n = (int)lua_rawlen(L, index);
	
	ozz::animation::offline::RawFloat3Track s_tracks, t_tracks;
	ozz::animation::offline::RawQuaternionTrack r_tracks;
	for (int i=0; i<n; ++i){
		lua_geti(L, index, i+1);
		const motion_keyframe kf = extract_keyframe(L, -1, w);
		lua_pop(L, 1);

		if (kf.s.ratio >= 0.f)
			s_tracks.keyframes.push_back(kf.s);
		
		if (kf.r.ratio >= 0.f) 
			r_tracks.keyframes.push_back(kf.r);

		if (kf.t.ratio >= 0.f)
			t_tracks.keyframes.push_back(kf.t);
	}
	ozz::animation::offline::TrackBuilder builder;
	mt->s = s_tracks.keyframes.empty() ? nullptr : builder(s_tracks);
	mt->r = r_tracks.keyframes.empty() ? nullptr : builder(r_tracks);
	mt->t = t_tracks.keyframes.empty() ? nullptr : builder(t_tracks);
}

static int
lcreate_tracks(lua_State *L){
	auto mt = new motion_tracks;
	auto w = getworld(L);
	build_tracks(L, w, 1, mt);
	lua_pushlightuserdata(L, mt);
	return 1;
}

static int
lbuild_tracks(lua_State *L){
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	auto mt = (struct motion_tracks*)lua_touserdata(L, 1);
	auto w = getworld(L);
	build_tracks(L, w, 2, mt);
	return 0;

}

static int
lnull_tracks(lua_State *L){
	lua_pushlightuserdata(L, nullptr);
	return 1;
}

static int
ldestory_tracks(lua_State *L){
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	auto mt = (struct motion_tracks*)lua_touserdata(L, 1);
	delete mt;
	return 0;
}

static void
math3d_update(struct math_context* math3d, math_t& id, math_t const& m) {
	int r = math_unmark(math3d, id);
	assert(r >= 0);
	(void)r;
	id = math_mark(math3d, m);
}

static int lsample(lua_State *L){
	auto w = getworld(L);

	const float delta = (float)luaL_checknumber(L, 2);

	//int gids[] = {gid};ecs::group_enable<component::motion_sampler_tag>(w->ecs, gids);
	
	for (auto& e : ecs::select<component::motion_sampler_tag, component::motion_sampler, component::scene>(w->ecs)) {
		auto &ms = e.get<component::motion_sampler>();
		auto mt = (struct motion_tracks*)ms.motion_tracks;
		if (nullptr == mt)
			continue;

        bool needupdate = true;
        if (ms.duration >= 0){
            needupdate = ms.current <= ms.duration && (!ms.stop);
            if (needupdate){
                ms.current = ms.current + (ms.is_tick ? 1.f : delta);
                ms.ratio = tween(std::min(1.f, ms.current / ms.duration), (tween_type)ms.tween_in, (tween_type)ms.tween_out);
			}
		}

        if (needupdate){
			auto &scene = e.get<component::scene>();
			auto M = w->math3d->M;

			if (mt->s.get()){
				ozz::animation::Float3TrackSamplingJob job;
				const math_t sid = math_import(M, NULL, MATH_TYPE_VEC4, 1);
				job.track = mt->s.get();
				job.result = (ozz::math::Float3*)(math_value(M, sid));
				job.ratio = ms.ratio;
				if (!job.Run()){
					luaL_error(L, "Sampling scale failed");
				}

				math3d_update(M, scene.s, sid);
			}

			if (mt->r.get()){
				ozz::animation::QuaternionTrackSamplingJob job;
				const math_t qid = math_import(M, NULL, MATH_TYPE_QUAT, 1);
				job.track = mt->r.get();
				job.result = (ozz::math::Quaternion*)math_value(M, qid);
				job.ratio = ms.ratio;
				if (!job.Run()){
					luaL_error(L, "Sampling rotation failed");
				}

				math3d_update(M, scene.r, qid);
			}

			if (mt->t.get()){
				ozz::animation::Float3TrackSamplingJob job;
				const math_t tid = math_import(M, NULL, MATH_TYPE_VEC4, 1);
				job.track = mt->t.get();
				job.result = (ozz::math::Float3*)(math_value(M, tid));
				job.ratio = ms.ratio;
				if (!job.Run()){
					luaL_error(L, "Sampling translation failed");
				}

				math3d_update(M, scene.t, tid);
			}
            e.enable_tag<component::scene_needchange>();
		}
	}
	return 0;
}

extern "C" int
luaopen_motion_sampler(lua_State *L) {
    luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create_tracks",	lcreate_tracks},
		{ "build_tracks",	lbuild_tracks},
		{ "destroy_tracks",	ldestory_tracks},
		{ "null",			lnull_tracks},
		{ "sample",			lsample},
		{ nullptr,			nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
    return 1;
}
