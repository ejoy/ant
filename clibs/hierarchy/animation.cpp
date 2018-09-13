#include "hierarchy.h"

extern "C" {
#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"
}

#include <ozz/animation/runtime/animation.h>
#include <ozz/animation/runtime/sampling_job.h>
#include <ozz/animation/runtime/local_to_model_job.h>
#include <ozz/animation/runtime/blending_job.h>

#include <ozz/animation/runtime/skeleton.h>

#include <ozz/base/maths/soa_transform.h>

//#include <ozz/animation/offline/raw_animation.h>

#include <ozz/base/memory/allocator.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/containers/vector.h>


struct animation_node {
	ozz::animation::Animation *ani;
	ozz::animation::SamplingCache *cache;

	ozz::Range<ozz::math::Float4x4>	poses;	
	float ratio;
};


static int
lblend(lua_State *L){

	return 0;
}

static int
ladditive(lua_State *L) {
	return 0;
}

static int 
lnew_layer(lua_State *L){
	return 1;
}

static int
lmotion(lua_State *L){
	luaL_checktype(L, 1, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 1);
	luaL_checktype(L, 2, LUA_TUSERDATA);
	animation_node * aninode = (animation_node*)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TNUMBER);

	float ratio = (float)lua_tonumber(L, 3);

	ozz::animation::Skeleton *ske = builddata->skeleton;

	if (aninode->cache == nullptr) {
		aninode->cache = ozz::memory::default_allocator()->New<ozz::animation::SamplingCache>(ske->num_joints());
	}

	auto samplingResults = ozz::memory::default_allocator()->AllocateRange<ozz::math::SoaTransform>(ske->num_soa_joints());

	ozz::animation::SamplingJob job;
	job.animation = aninode->ani;
	job.cache = aninode->cache;
	job.ratio = ratio;
	job.output = samplingResults;

	if (!job.Run()) {
		luaL_error(L, "run sampling job failed!");
	}

	if (aninode->poses.size() == 0)
		aninode->poses = ozz::memory::default_allocator()->AllocateRange<ozz::math::Float4x4>(ske->num_soa_joints());

	ozz::animation::LocalToModelJob ltmjob;
	ltmjob.input = samplingResults;
	ltmjob.skeleton = ske;
	ltmjob.output = aninode->poses;

	if (!ltmjob.Run()) {
		luaL_error(L, "transform from local to model failed!");
	}

	return 0;
}

static int
ldel_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	animation_node *node = (animation_node*)lua_touserdata(L, 1);
	ozz::memory::default_allocator()->Delete(node->ani);
	if (node->cache) {
		ozz::memory::default_allocator()->Delete(node->cache);
		node->cache = nullptr;
	}

	ozz::memory::default_allocator()->Deallocate(node->poses);
	
	return 0;
}

static int
lnew_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);
	const char * path = lua_tostring(L, 1);

	animation_node *node = (animation_node*)lua_newuserdata(L, sizeof(animation_node));
	luaL_getmetatable(L, "ANIMATION_NODE");
	lua_setmetatable(L, -2);

	node->ani = ozz::memory::default_allocator()->New<ozz::animation::Animation>();	
	node->cache = nullptr;

	ozz::io::File file(path, "rb");
	if (!file.opened()) {
		luaL_error(L, "file could not open : %s", path);
	}

	ozz::io::IArchive archive(&file);
	if (!archive.TestTag<ozz::animation::Animation>()) {		
		luaL_error(L, "file is not ozz::animation, file : %s", path);
	}
	archive >> *(node->ani);
	return 1;
}

extern "C" {
LUAMOD_API int
luaopen_hierarchy_animation(lua_State *L) {
	luaL_newmetatable(L, "ANIMATION_NODE");
	//lua_pushcfunction(L, );
	//lua_setfield("__")

	lua_pushcfunction(L, ldel_animation);
	lua_setfield(L, -2, "__gc");

	//ozz::animation::Animation ani;



	luaL_Reg l[] = {
		{ "blend", lblend },
		{ "additive", ladditive},
		{ "new_layer", lnew_layer },
		{ "motion", lmotion},
		{ "new_ani", lnew_animation},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

}