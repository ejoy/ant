#include "pch.h"
#include "lua2struct.h"
#include "particle.inl"
#include "particle_mgr.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

LUA2STRUCT(struct render_data, viewid, progid, qb, textures);
LUA2STRUCT(struct render_data::texture, stage, uniformid, texid);

namespace lua_struct{
    template<>
    void unpack(lua_State* L, int index, quad_buffer& qb, void*) {
        if (LUA_TNUMBER == lua_getfield(L, index, "ib")){
            qb.ib.idx = (uint16_t)lua_tonumber(L, -1);
        } else {
            luaL_error(L, "invalid 'ib'");
        }
        lua_pop(L, 1);
        if (LUA_TUSERDATA == lua_getfield(L, index, "layout")){
            qb.layout = (bgfx_vertex_layout_t*)lua_touserdata(L, -1);
        } else {
            luaL_error(L, "invalid pointer");
        }
        lua_pop(L, 1);
    }
    template<>
    void pack(lua_State* L, const quad_buffer& qb, void*){}
}

#ifdef _DEBUG
const char* g_component_names[ID_count] = {
    "ID_life = 0",
    "ID_spawn",
    "ID_velocity",
    "ID_acceleration",
    "ID_scale",
    "ID_rotation",
    "ID_translation",
    "ID_color",
    "ID_uv",
    "ID_uv_motion",
    "ID_subuv",
    "ID_material",

    "ID_velocity_interpolator",
    "ID_acceleration_interpolator",
    "ID_scale_interpolator",
    "ID_rotation_interpolator",
    "ID_translation_interpolator",
    "ID_uv_motion_interpolator",
    "ID_color_interpolator",
    "ID_subuv_index_interpolator",

    "ID_TAG_emitter",
    "ID_TAG_render_quad",
    "ID_TAG_material",
};

const char* get_component_name(component_id id){
	return g_component_names[id];
}

static_assert(ID_count == sizeof(g_component_names)/sizeof(g_component_names[0]));

static inline const char*
component_id_name(component_id id) { return g_component_names[id]; }


#endif //_DEBUG

particle_mgr::particle_mgr()
    : mmgr(particlesystem_create()){
}

particle_mgr::~particle_mgr(){
    particlesystem_release(mmgr);
}

template<typename T>
T* particle_mgr::sibling_component(component_id id, int ii){
	const auto idx = particlesystem_component(mmgr, id, ii, T::ID());
	return (idx != PARTICLE_INVALID) ? &(data<T>()[idx]) : nullptr;
}

#ifdef _DEBUG
static inline bool
check_dup_id(const comp_ids &ids){
	int checkids[ID_count] = {0};
	for (auto id:ids){
		++checkids[id];
		if (checkids[id] > 1){
			return false;
		}
	}
	return true;
}
#endif //_DEBUG

bool particle_mgr::add(const comp_ids &ids){
	#ifdef _DEBUG
	assert(check_dup_id(ids) && "find dup id");
	#endif //_DEBUG

	const bool valid = 0 != particlesystem_add(mmgr, (int)ids.size(), (const int*)(&ids.front()));
	if (!valid)
		mparticles.pop_back(ids);
	return valid;
}

void
particle_mgr::remove_particle(uint32_t pidx){
	particlesystem_remove(mmgr, ID_life, (particle_index)pidx);
}

void
particle_mgr::update_lifetime(float dt){
	auto &lifes = data<particles::life>();
	for (size_t ii=0; ii<lifes.size(); ++ii){
		auto &c = lifes[ii];
		c.current += dt;
		if (c.update_process())
			remove_particle((uint32_t)ii);
    }
}

void
particle_mgr::update_velocity(float dt){
	const auto &acc = data<particles::acceleration>();
	for (int aidx=0; aidx<(int)acc.size(); ++aidx){
		const auto &a = acc[aidx];
		auto v = sibling_component<particles::velocity>(ID_acceleration, aidx);
		*v += a * dt;
	}
}

void
particle_mgr::update_translation(float dt){
	const auto &vel = data<particles::velocity>();
	for (int vidx=0; vidx<(int)vel.size(); ++vidx){
		const auto &v = vel[vidx];
		auto t = sibling_component<particles::translation>(ID_velocity, vidx);
		*t += v * dt;
	}
}

void
particle_mgr::update_lifetime_scale(float dt){
	const auto &scale_interpolators = data<particles::scale_interpolator>();
	for (int ii=0; ii<(int)scale_interpolators.size(); ++ii){
		const auto life = sibling_component<particles::life>(ID_scale_interpolator, ii);
		auto scale = sibling_component<particles::scale>(ID_scale_interpolator, ii);
		auto &si = scale_interpolators[ii];
		*scale = si.get(*scale, life->delta_process(dt));
	}
}

void
particle_mgr::update_lifetime_rotation(float dt){

}

void
particle_mgr::update_lifetime_color(float dt){
	const auto &color_interpolators = data<particles::color_interpolator>();
	for(int ii=0; ii<(int)color_interpolators.size(); ++ii){
		auto &clr = *sibling_component<particles::color>(ID_color_interpolator, ii);
		const auto life = sibling_component<particles::life>(ID_color_interpolator, ii);

		const auto& ci = color_interpolators[ii];
		for (int iv = 0; iv < 4; ++iv) {
			for (int ii = 0; ii < 4; ++ii) {
				const auto& c = ci.rgba[ii];
				clr[ii] = to_color_channel(c.get(to_color_channel(clr[ii]), life->delta_process(dt)));
			}
		}
	}
}

void
particle_mgr::update_lifetime_subuv_index(float dt){
	// const auto &subuv_index_interpolators = data<particles::subuv_index_interpolator>();
	// for (int ii=0; ii<(int)subuv_index_interpolators.size(); ++ii){
	// 	const auto &subuv_index = subuv_index_interpolators[ii];
	// 	const auto subuv = sibling_component<particles::subuv>(ID_subuv_index_interpolator, ii);
	// 	const auto life = sibling_component<particles::life>(ID_subuv_index_interpolator, ii);
	// 	subuv->index = subuv_index.get(subuv->index, life->delta_process(dt));
	// }
}

void
particle_mgr::update_uv_motion(float dt){
	const auto &uvmotions = data<particles::uv_motion>();
	for (int ii=0; ii<(int)uvmotions.size(); ++ii){
		auto& quv = *sibling_component<particles::uv>(ID_uv_motion, ii);
		const auto &uvm = uvmotions[ii];
		for (int ii=0; ii<4; ++ii){
			quv.uv[ii] = dt * uvm;
		}
	}
}

uint32_t particle_mgr::submit_buffer(){
	const int n = particlesystem_count(mmgr, ID_TAG_render_quad);
	if (n == 0)
		return 0;
	bgfx_transient_vertex_buffer_t tvb;
	mrenderdata.qb.alloc(n, tvb);

	quaddata* quads = (quaddata*)tvb.data;

	for (int iq=0; iq<n; ++iq){
		const auto scale = sibling_component<particles::scale>(ID_TAG_render_quad, iq);
		const auto rotation = sibling_component<particles::rotation>(ID_TAG_render_quad, iq);
		const auto translation = sibling_component<particles::translation>(ID_TAG_render_quad, iq);

		glm::mat4 m = scale ? glm::scale(*scale) : glm::mat4(1.f);
		if (rotation)
			m = glm::mat4(*rotation) * m;

		if (translation)
			m = glm::translate(*translation) * m;

		quaddata& q = quads[iq];
		const auto &dq = quaddata::default_quad();
		for (int ii=0; ii<4; ++ii){
			q[ii].p = m * glm::vec4(dq[ii].p, 1.f);
		}
		
		const auto quv = sibling_component<particles::uv>(ID_TAG_render_quad, iq);
		if (quv){
			for (int ii=0; ii<4; ++ii){
				q[ii].uv = quv->uv[ii];
			}
		} else {
			for (int ii=0; ii<4; ++ii){
				q[ii].uv = dq[ii].uv;
			}
		}
		//TODO: calculate subuv by subuv->index
		//const auto qsubuv = sibling_component<particles::subuv>(ID_TAG_render_quad, iq);

		const auto qclr = sibling_component<particles::color>(ID_TAG_render_quad, iq);
		if (qclr){
			for (int ii=0; ii<4; ++ii){
				q[ii].color = *((uint32_t*)&qclr);
			}
		}

	}

	mrenderdata.qb.submit(tvb);
	return n;
}

void
particle_mgr::submit_render(){
	if (0 == submit_buffer())
		return;

	BGFX(set_state(uint64_t(BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA), 0));
	

	for (size_t ii=0; ii<mrenderdata.textures.size(); ++ii){
		const auto &t = mrenderdata.textures[ii];
		BGFX(set_texture)((uint8_t)ii, {t.uniformid}, {t.texid}, UINT16_MAX);
	}
	
	BGFX(submit)(mrenderdata.viewid, {mrenderdata.progid}, 0, BGFX_DISCARD_ALL);
}

void
particle_mgr::update(float dt){
	update_velocity(dt);
	update_translation(dt);
	update_uv_motion(dt);
	update_lifetime_color(dt);
	update_lifetime_scale(dt);

	update_lifetime(dt);	// should be last update
	remap_particles();
	assert(0 == particlesystem_verify(mmgr));

	submit_render();
}
