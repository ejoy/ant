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

#include <ozz/geometry/runtime/skinning_job.h>

#include <ozz/base/maths/soa_transform.h>

#include <ozz/base/memory/allocator.h>
#include <ozz/base/io/stream.h>
#include <ozz/base/io/archive.h>
#include <ozz/base/containers/vector.h>

// for ozz/sample
#include <ozz-animation/samples/framework/mesh.h>
#include <ozz-animation/samples/framework/utils.h>


// stl
#include <algorithm>

struct animation_node {
	ozz::animation::Animation		*ani;
	ozz::Range<ozz::math::Float4x4>	poses;
	float ratio;
};

struct sampling_node {
	ozz::animation::SamplingCache *		cache;
	ozz::Range<ozz::math::SoaTransform>	results;
};

struct ozzmesh {
	ozz::sample::Mesh* mesh;
	ozz::Range<ozz::math::Float4x4>	skinning_matrices;

	uint8_t * dynamic_buffer;
	uint8_t * static_buffer;
};


static int
lblend(lua_State *L){

	return 0;
}

static int
ladditive(lua_State *L) {
	return 0;
}

static size_t 
dynamic_vertex_elem_stride(ozzmesh *om) {
	auto mesh = om->mesh;
	if (mesh->parts.empty()) {
		return 0;
	}

	const auto &part = mesh->parts.back();
	assert(!part.positions.empty());

	size_t num_elem = ozz::sample::Mesh::Part::kPositionsCpnts;
	if (!part.normals.empty())
		num_elem += ozz::sample::Mesh::Part::kNormalsCpnts;

	if (!part.tangents.empty())
		num_elem += ozz::sample::Mesh::Part::kTangentsCpnts;

	return sizeof(float) * num_elem;		
}

static size_t 
static_vertex_elem_stride(ozzmesh *om) {
	auto mesh = om->mesh;
	if (mesh->parts.empty())
		return 0;

	const auto &part = mesh->parts.back();
	assert(!part.positions.empty());

	size_t stride = 0;
	if (!part.colors.empty())
		stride += ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t);

	if (!part.uvs.empty())
		stride += ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float);

	return stride;
}

static int
llayout_ozzmesh(lua_State *L) {
	int numarg = lua_gettop(L);
	if (numarg < 2) {
		luaL_error(L, "need 1: ozzmesh, 2: type(dynamic/static) two argument");
		return 0;
	}
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);
	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);
	
	const char *deflayout = "_30NIf";
	auto mesh = om->mesh;

	auto &part = mesh->parts.back();

	std::string layout;
	if (strcmp(type, "dynamic") == 0) {
		std::string pos(deflayout);
		pos[0] = 'p';
		layout = pos;

		if (!part.normals.empty()) {
			std::string normal(deflayout);
			normal[0] = 'n';
			normal[1] = '0' + ozz::sample::Mesh::Part::kNormalsCpnts;
			layout += "|" + normal;
		}

		if (!part.tangents.empty()) {
			std::string tangent(deflayout);
			tangent[0] = 'T';
			tangent[1] = '0' + ozz::sample::Mesh::Part::kTangentsCpnts;
			layout += "|" + tangent;
		}

	} else if (strcmp(type, "static") == 0) {
		if (!part.colors.empty()) {
			std::string color(deflayout);
			color[0] = 'c';
			color[1] = '0' + ozz::sample::Mesh::Part::kColorsCpnts;
			color[3] = 'n';
			color[5] = 'u';
			layout = color;		
		}

		if (!part.uvs.empty()) {
			std::string uv(deflayout);
			uv[0] = 't';
			uv[1] = '0' + ozz::sample::Mesh::Part::kUVsCpnts;
			if (layout.empty())
				layout = uv;
			else
				layout += "|" + uv;
		}
	} else {
		luaL_error(L, "not support type : %s", type);
	}

	lua_pushstring(L, layout.c_str());
	return 1;
}

static int
lskinning(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 2);

	luaL_checktype(L, 3, LUA_TUSERDATA);
	animation_node *ani = (animation_node*)lua_touserdata(L, 3);
	assert(om->mesh);

	auto &mesh = *(om->mesh);

	for (size_t ii = 0; ii < mesh.joint_remaps.size(); ++ii) {
		om->skinning_matrices[ii] =
			ani->poses[mesh.joint_remaps[ii]] * mesh.inverse_bind_poses[ii];
	}

	const size_t vertex_count = mesh.vertex_count();

	// offset
	const size_t positions_offset = 0;
	const size_t normals_offset = sizeof(float) * ozz::sample::Mesh::Part::kPositionsCpnts;
	const size_t tangents_offset = normals_offset + sizeof(float) * (ozz::sample::Mesh::Part::kNormalsCpnts);

	// stride
	const size_t positions_stride = sizeof(float) * (ozz::sample::Mesh::Part::kPositionsCpnts 
													+ ozz::sample::Mesh::Part::kNormalsCpnts 
													+ ozz::sample::Mesh::Part::kTangentsCpnts);
	const size_t normals_stride = positions_stride;
	const size_t tangents_stride = positions_stride;

	size_t processed_vertex_count = 0;
	for (const auto& part : mesh.parts) {
		const size_t part_vertex_count = part.vertex_count();
		if (part_vertex_count == 0)
			continue;

		// Fills the job.
		ozz::geometry::SkinningJob skinning_job;
		skinning_job.vertex_count = static_cast<int>(part_vertex_count);
		const int part_influences_count = part.influences_count();

		// Clamps joints influence count according to the option.
		skinning_job.influences_count = part_influences_count;

		// Setup skinning matrices, that came from the animation stage before being
		// multiplied by inverse model-space bind-pose.
		skinning_job.joint_matrices = om->skinning_matrices;

		// Setup joint's indices.
		skinning_job.joint_indices = make_range(part.joint_indices);
		skinning_job.joint_indices_stride =
			sizeof(uint16_t) * part_influences_count;

		// Setup joint's weights.
		if (part_influences_count > 1) {
			skinning_job.joint_weights = make_range(part.joint_weights);
			skinning_job.joint_weights_stride =
				sizeof(float) * (part_influences_count - 1);
		}

		// Setup input positions, coming from the loaded mesh.
		skinning_job.in_positions = make_range(part.positions);
		skinning_job.in_positions_stride =
			sizeof(float) * ozz::sample::Mesh::Part::kPositionsCpnts;

		// Setup output positions, coming from the rendering output mesh buffers.
		// We need to offset the buffer every loop.
		skinning_job.out_positions.begin = reinterpret_cast<float*>(
			ozz::PointerStride(om->dynamic_buffer, positions_offset + processed_vertex_count *
				positions_stride));
		skinning_job.out_positions.end = ozz::PointerStride(
			skinning_job.out_positions.begin, part_vertex_count * positions_stride);
		skinning_job.out_positions_stride = positions_stride;

		// Setup normals if input are provided.
		float* out_normal_begin = reinterpret_cast<float*>(ozz::PointerStride(
			om->dynamic_buffer, normals_offset + processed_vertex_count * normals_stride));
		const float* out_normal_end = ozz::PointerStride(
			out_normal_begin, part_vertex_count * normals_stride);

		if (part.normals.size() / ozz::sample::Mesh::Part::kNormalsCpnts ==
			part_vertex_count) {
			// Setup input normals, coming from the loaded mesh.
			skinning_job.in_normals = make_range(part.normals);
			skinning_job.in_normals_stride =
				sizeof(float) * ozz::sample::Mesh::Part::kNormalsCpnts;

			// Setup output normals, coming from the rendering output mesh buffers.
			// We need to offset the buffer every loop.
			skinning_job.out_normals.begin = out_normal_begin;
			skinning_job.out_normals.end = out_normal_end;
			skinning_job.out_normals_stride = normals_stride;
		} else {
			// Fills output with default normals.
			for (float* normal = out_normal_begin; normal < out_normal_end;
				normal = ozz::PointerStride(normal, normals_stride)) {
				normal[0] = 0.f;
				normal[1] = 1.f;
				normal[2] = 0.f;
			}
		}

		// Setup tangents if input are provided.
		float* out_tangent_begin = reinterpret_cast<float*>(ozz::PointerStride(
			om->dynamic_buffer, tangents_offset + processed_vertex_count * tangents_stride));
		const float* out_tangent_end = ozz::PointerStride(
			out_tangent_begin, part_vertex_count * tangents_stride);

		if (part.tangents.size() / ozz::sample::Mesh::Part::kTangentsCpnts ==
			part_vertex_count) {
			// Setup input tangents, coming from the loaded mesh.
			skinning_job.in_tangents = make_range(part.tangents);
			skinning_job.in_tangents_stride =
				sizeof(float) * ozz::sample::Mesh::Part::kTangentsCpnts;

			// Setup output tangents, coming from the rendering output mesh buffers.
			// We need to offset the buffer every loop.
			skinning_job.out_tangents.begin = out_tangent_begin;
			skinning_job.out_tangents.end = out_tangent_end;
			skinning_job.out_tangents_stride = tangents_stride;
		} else {
			// Fills output with default tangents.
			for (float* tangent = out_tangent_begin; tangent < out_tangent_end;
				tangent = ozz::PointerStride(tangent, tangents_stride)) {
				tangent[0] = 1.f;
				tangent[1] = 0.f;
				tangent[2] = 0.f;
			}
		}

		// Execute the job, which should succeed unless a parameter is invalid.
		if (!skinning_job.Run()) {
			return false;
		}
	}

	return 0;
}

static int
lmotion(lua_State *L){
	luaL_checktype(L, 1, LUA_TUSERDATA);
	hierarchy_build_data *builddata = (hierarchy_build_data *)lua_touserdata(L, 1);

	auto ske = builddata->skeleton;
	if (ske == nullptr) {
		luaL_error(L, "skeleton is not init!");
	}

	luaL_checktype(L, 2, LUA_TUSERDATA);
	animation_node * aninode = (animation_node*)lua_touserdata(L, 2);
	if (aninode->ani == nullptr) {
		luaL_error(L, "animation is not init!");
		return 0;
	}

	if (aninode->poses.count() != ske->num_joints()) {
		luaL_error(L, 
			"skeleton joint number : %d, is not the same as animation result poses number : %d", 
			ske->num_joints(), aninode->poses.count());
		return 0;
	}

	luaL_checktype(L, 3, LUA_TUSERDATA);
	sampling_node * samplingnode = (sampling_node*)lua_touserdata(L, 3);
	if (samplingnode->results.count() != ske->num_soa_joints()) {
		luaL_error(L,
			"sampling node results number : %d, is not the same as ske num_soa_joints number: %d",
			samplingnode->results.count(), ske->num_soa_joints());
		return 0;
	}

	luaL_checktype(L, 4, LUA_TNUMBER);
	float ratio = (float)lua_tonumber(L, 4);	
	ratio = std::min(1.f, std::max(0.f, ratio));


	ozz::animation::SamplingJob job;
	job.animation = aninode->ani;
	job.cache = samplingnode->cache;
	job.ratio = ratio;
	job.output = samplingnode->results;

	if (!job.Run()) {
		luaL_error(L, "run sampling job failed!");
	}

	ozz::animation::LocalToModelJob ltmjob;
	ltmjob.input	= samplingnode->results;
	ltmjob.skeleton = builddata->skeleton;
	ltmjob.output	= aninode->poses;

	if (!ltmjob.Run()) {
		luaL_error(L, "transform from local to model failed!");
	}

	return 0;
}

static int
lnew_layer(lua_State *L) {
	return 1;
}

static int
ldel_sampling(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	sampling_node *sampling = (sampling_node *)lua_touserdata(L, 1);
	ozz::memory::default_allocator()->Delete(sampling->cache);
	ozz::memory::default_allocator()->Deallocate(sampling->results);

	return 0;
}

static int
lnew_sampling_cache(lua_State *L) {
	luaL_checktype(L, 1, LUA_TNUMBER);
	const int numjoints = (int)lua_tointeger(L, 1);

	if (numjoints <= 0) {
		luaL_error(L, "joints number should be > 0");
		return 0;
	}

	sampling_node* samplingnode = (sampling_node*)lua_newuserdata(L, sizeof(sampling_node));
	luaL_getmetatable(L, "SAMPLING_NODE");
	lua_setmetatable(L, -2);

	samplingnode->cache = ozz::memory::default_allocator()->New<ozz::animation::SamplingCache>(numjoints);
	const int num_soa_joints = (numjoints + 3) / 4;
	samplingnode->results = ozz::memory::default_allocator()->AllocateRange<ozz::math::SoaTransform>(num_soa_joints);

	return 1;
}

static int
ldel_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	animation_node *node = (animation_node*)lua_touserdata(L, 1);
	ozz::memory::default_allocator()->Delete(node->ani);
	ozz::memory::default_allocator()->Deallocate(node->poses);
	
	return 0;
}

static int
lnew_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);
	const char * path = lua_tostring(L, 1);

	const int numjoints = (int)luaL_optinteger(L, 2, 0);
	
	animation_node *node = (animation_node*)lua_newuserdata(L, sizeof(animation_node));
	luaL_getmetatable(L, "ANIMATION_NODE");
	lua_setmetatable(L, -2);
	if (numjoints > 0){
		node->poses = ozz::memory::default_allocator()->AllocateRange<ozz::math::Float4x4>(numjoints);
	} else {
		node->poses = ozz::Range<ozz::math::Float4x4>();
	}
	
	node->ani = ozz::memory::default_allocator()->New<ozz::animation::Animation>();

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

static int
lduration_animation(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	animation_node *node = (animation_node*)lua_touserdata(L, 1);
	lua_pushnumber(L, node->ani->duration());
	return 1;
}

static int
lresize_animation_poses(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	animation_node *ani = (animation_node*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TNUMBER);
	const int num_joints = (int)lua_tointeger(L, 2);

	ozz::memory::default_allocator()->Deallocate(ani->poses);
	ani->poses = ozz::memory::default_allocator()->AllocateRange<ozz::math::Float4x4>(num_joints);
	return 0;
}

static int
ldel_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);

	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	if (om->mesh) {
		ozz::memory::default_allocator()->Delete(om->mesh);
		ozz::memory::default_allocator()->Deallocate(om->skinning_matrices);
	}

	if (om->dynamic_buffer) {
		delete[] om->dynamic_buffer;
		om->dynamic_buffer = nullptr;
	}

	if (om->static_buffer) {
		delete[] om->static_buffer;
		om->static_buffer = nullptr;
	}

	return 0;
}

static int
lnew_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TSTRING);

	const char* filename = lua_tostring(L, 1);

	ozzmesh *om = (ozzmesh*)lua_newuserdata(L, sizeof(ozzmesh));
	luaL_getmetatable(L, "OZZMESH");
	lua_setmetatable(L, -2);

	om->mesh = ozz::memory::default_allocator()->New<ozz::sample::Mesh>();
	ozz::sample::LoadMesh(filename, om->mesh);

	if (!om->mesh->inverse_bind_poses.empty()) {
		om->skinning_matrices = ozz::memory::default_allocator()->AllocateRange<ozz::math::Float4x4>(om->mesh->inverse_bind_poses.size());
	} else {
		om->skinning_matrices = ozz::Range<ozz::math::Float4x4>();
	}

	const auto num_vertices = om->mesh->vertex_count();

	const size_t dynamic_stride = dynamic_vertex_elem_stride(om);
	if (dynamic_stride != 0) {
		om->dynamic_buffer = new uint8_t[dynamic_stride * num_vertices];
		auto *db = om->dynamic_buffer;
		const size_t posstep = ozz::sample::Mesh::Part::kPositionsCpnts * sizeof(float);
		const size_t normalstep = ozz::sample::Mesh::Part::kNormalsCpnts * sizeof(float);
		const size_t tangentstep = ozz::sample::Mesh::Part::kTangentsCpnts * sizeof(float);

		for (const auto &part : om->mesh->parts) {
			assert(0 != part.vertex_count());
			for (auto iv = 0; iv < part.vertex_count(); ++iv) {				
				memcpy(db, &(part.positions[iv * ozz::sample::Mesh::Part::kPositionsCpnts]), posstep);
				db += posstep;
				
				if (!part.normals.empty()) {
					memcpy(db, &(part.normals[iv * ozz::sample::Mesh::Part::kNormalsCpnts]), normalstep);
					db += normalstep;
				}

				if (!part.tangents.empty()) {
					memcpy(db, &(part.tangents[iv * ozz::sample::Mesh::Part::kTangentsCpnts]), tangentstep);
					db += tangentstep;
				}
			}
		}
	} else {
		om->dynamic_buffer = nullptr;	
	}

	const size_t static_stride = static_vertex_elem_stride(om);
	if (static_stride != 0) {
		om->static_buffer = new uint8_t[static_stride * num_vertices];
		uint8_t *sb = om->static_buffer;
		const size_t colorstep = ozz::sample::Mesh::Part::kColorsCpnts * sizeof(uint8_t);
		const size_t uvstep = ozz::sample::Mesh::Part::kUVsCpnts * sizeof(float);
		for (const auto &part : om->mesh->parts) {
			for (auto iv = 0; iv < part.vertex_count(); ++iv) {
				if (!part.colors.empty()) {
					memcpy(sb, &(part.colors[iv * ozz::sample::Mesh::Part::kColorsCpnts]), colorstep);
					sb += colorstep;
				}
				if (!part.uvs.empty()) {
					memcpy(sb, &(part.uvs[iv * ozz::sample::Mesh::Part::kUVsCpnts]), uvstep);
					sb += uvstep;
				}
			}
		}
	} else {
		om->static_buffer = nullptr;
	}

	return 1;
}

static int 
lbuffer_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	luaL_checktype(L, 2, LUA_TSTRING);
	const char* type = lua_tostring(L, 2);

	size_t vertex_stride = 0;
	uint8_t * buffer = nullptr;
	if (strcmp(type, "dynamic") == 0) {
		buffer = om->dynamic_buffer;
		vertex_stride = dynamic_vertex_elem_stride(om);
	} else if (strcmp(type, "static") == 0) {
		buffer = om->static_buffer;
		vertex_stride = static_vertex_elem_stride(om);
	} else {
		luaL_error(L, "not support type : %s", type);
	}
	
	lua_pushlightuserdata(L, buffer);
	lua_pushinteger(L, lua_Integer(vertex_stride * om->mesh->vertex_count()));
	return 2;
}

static int
lindexbuffer_ozzmesh(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	ozzmesh *om = (ozzmesh*)lua_touserdata(L, 1);

	auto mesh = om->mesh;

	lua_pushlightuserdata(L, ozz::array_begin(mesh->triangle_indices));
	const size_t sizeInBytes = mesh->triangle_index_count() * sizeof(uint16_t);
	lua_pushinteger(L, lua_Integer(sizeInBytes));
	lua_pushinteger(L, sizeof(uint16_t));

	return 3;
}

static void 
register_animation_mt(lua_State *L) {
	luaL_newmetatable(L, "ANIMATION_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");	// ANIMATION_NODE.__index = ANIMATION_NODE

	luaL_Reg l[] = {
		"resize",	lresize_animation_poses,
		"duration", lduration_animation,
		"__gc", ldel_animation,
		nullptr, nullptr,
	};

	luaL_setfuncs(L, l, 0);
}

static void
register_sampling_mt(lua_State *L) {
	luaL_newmetatable(L, "SAMPLING_NODE");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {
		"__gc", ldel_sampling,
		nullptr, nullptr,
	};

	luaL_setfuncs(L, l, 0);
}

static void
register_ozzmesh_mt(lua_State *L) {
	luaL_newmetatable(L, "OZZMESH");
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_Reg l[] = {		
		"buffer", lbuffer_ozzmesh,
		"index_buffer", lindexbuffer_ozzmesh,
		"layout", llayout_ozzmesh,		
		"__gc", ldel_ozzmesh,
		nullptr, nullptr,
	};

	luaL_setfuncs(L, l, 0);
}

extern "C" {
LUAMOD_API int
luaopen_hierarchy_animation(lua_State *L) {
	register_animation_mt(L);
	register_sampling_mt(L);
	register_ozzmesh_mt(L);

	luaL_Reg l[] = {
		{ "blend", lblend },
		{ "additive", ladditive},
		{ "skinning", lskinning},
		{ "new_layer", lnew_layer },
		{ "motion", lmotion},
		{ "new_ani", lnew_animation},
		{ "new_ozzmesh", lnew_ozzmesh},
		{ "new_sampling_cache", lnew_sampling_cache},
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

}