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

static inline motion_tracks*
MT(lua_State *L, int index = 1){
	return (motion_tracks*)luaL_checkudata(L, index, "TRACKS_MT");
}

static int
ltracks_delete(lua_State *L){
	auto mt = MT(L);

	mt->s = nullptr;
	mt->r = nullptr;
	mt->t = nullptr;

	mt->~motion_tracks();
	return 0;
}

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

static inline void *
MATH_TO_HANDLE(math_t id) {
	return (void *)id.idx;
}

static inline void
lua_pushmath(lua_State *L, math_t id) {
	lua_pushlightuserdata(L, MATH_TO_HANDLE(id));
}

static int
ltracks_sample(lua_State *L){
	auto mt = MT(L);
	auto w = getworld(L);
	const float ratio = (float)luaL_checknumber(L, 2);
	const auto M = w->math3d->M;

	auto sample_track = [L](auto track, float ratio, const char* errmsg, auto tomathid){
		using TrackType = std::remove_pointer_t<decltype(track)>;

		if (track){
			typename TrackType::ValueType result;
			ozz::animation::internal::TrackSamplingJob<TrackType> job;
			job.track = track;
			job.result = &result;
			job.ratio = ratio;
			if (!job.Run()){
				luaL_error(L, errmsg);
			}

			lua_pushmath(L, tomathid(result));
		} else {
			lua_pushnil(L);
		}
	};

	ozz::animation::Float3Track track;

	sample_track(mt->s.get(), ratio, "Sampling scale track failed", [M](const ozz::math::Float3 &result){
		float v[] = {result.x, result.y, result.z, 0.f};
		return math_vec4(M, v);
	});

	sample_track(mt->r.get(), ratio, "Sampling rotation track failed", [M](const ozz::math::Quaternion &result){
		return math_quat(M, &result.x);
	});

	sample_track(mt->t.get(), ratio, "Sampling translation track failed", [M](const ozz::math::Float3 &result){
		float v[] = {result.x, result.y, result.z, 1.f};
		return math_vec4(M, v);
	});

	return 3;
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
ltracks_build(lua_State *L){
	auto mt = MT(L);
	auto w = getworld(L);
	build_tracks(L, w, 2, mt);
	return 0;
}

static inline void
check_ecs_world_in_upvalue1(lua_State *L){
	luaL_checkstring(L, lua_upvalueindex(1));
}

static int
lcreate_tracks(lua_State *L){
	auto mt = (motion_tracks*)lua_newuserdatauv(L, sizeof(motion_tracks), 0);
	new (mt) motion_tracks();

	auto w = getworld(L);
	if (!lua_isnoneornil(L, 1)){
		build_tracks(L, w, 1, mt);
	}

	if (luaL_newmetatable(L, "TRACKS_MT")){

		luaL_Reg l[] = {
			{ "sample",		ltracks_sample},
			{ "build",		ltracks_build},
			{ "__gc",		ltracks_delete},
			{ nullptr, 		nullptr},
		};
		check_ecs_world_in_upvalue1(L);
		lua_pushvalue(L, lua_upvalueindex(1));
		luaL_setfuncs(L, l, 1);

		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}

	lua_setmetatable(L, -2);
	return 1;
}

extern "C" int
luaopen_motion_sampler(lua_State *L) {
    luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "create_tracks",	lcreate_tracks},
		{ nullptr,			nullptr },
	};
	luaL_newlibtable(L,l);
	lua_pushnil(L);
	luaL_setfuncs(L,l,1);
    return 1;
}
