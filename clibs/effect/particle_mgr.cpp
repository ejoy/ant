#include "pch.h"
#include "lua2struct.h"
#include "particle.inl"
#include "particle_mgr.h"
#include "debug_print.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

LUA2STRUCT(struct render_data, viewid, qb);
LUA2STRUCT(struct material, fx, state, properties);
LUA2STRUCT(struct material::properties, uniforms, textures);
LUA2STRUCT(struct material::fx, prog);
LUA2STRUCT(struct material::uniform, uniformid, value);
LUA2STRUCT(struct material::texture, stage, texid, uniformid);

namespace lua_struct {
	static int inline
		hex2n(lua_State* L, char c) {
		if (c >= '0' && c <= '9')
			return c - '0';
		else if (c >= 'A' && c <= 'F')
			return c - 'A' + 10;
		else if (c >= 'a' && c <= 'f')
			return c - 'a' + 10;
		return luaL_error(L, "Invalid state %c", c);
	}

	static inline void
		get_state(lua_State* L, int idx, uint64_t* pstate, uint32_t* prgba) {
		size_t sz;
		const uint8_t* data = (const uint8_t*)luaL_checklstring(L, idx, &sz);
		if (sz != 16 && sz != 24) {
			luaL_error(L, "Invalid state length %d", sz);
		}
		uint64_t state = 0;
		uint32_t rgba = 0;
		int i;
		for (i = 0; i < 15; i++) {
			state |= hex2n(L, data[i]);
			state <<= 4;
		}
		state |= hex2n(L, data[15]);
		if (sz == 24) {
			for (i = 0; i < 7; i++) {
				rgba |= hex2n(L, data[16 + i]);
				rgba <<= 4;
			}
			rgba |= hex2n(L, data[23]);
		}
		*pstate = state;
		*prgba = rgba;
	}

	template <>
	void unpack<struct material::state>(lua_State* L, int idx, struct material::state& v, void*) {
		luaL_checktype(L, idx, LUA_TSTRING);
		get_state(L, -1, &v.state, &v.rgba);
	}
	template <>
	void pack<struct material::state>(lua_State* L, struct material::state const& v, void*) {}
}

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
		const uint16_t dp = life->delta_process(dt);
		for (int ii = 0; ii < 4; ++ii) {
			const auto& c = ci.rgba[ii];
			clr[ii] = c.get(clr[ii], dp);
		}
	}
}

void
particle_mgr::update_uv_motion(float dt){
	auto update_uvmotions = [dt](auto& uvmotions, auto op) {
		for (int ii = 0; ii < (int)uvmotions.size(); ++ii) {
			auto& quv = op(ii);
			auto& uvm = uvmotions[ii];
			for (int ii = 0; ii < 4; ++ii) {
				uvm.step(dt, quv);
			}
		}
	};

	update_uvmotions(data<particles::uv_motion>(), [this](int ii)->particles::uv&{
		return (*(this->sibling_component<particles::uv>(ID_uv_motion, ii)));
	});
	update_uvmotions(data<particles::subuv_motion>(), [this](int ii)->particles::subuv&{
		return (*(this->sibling_component<particles::subuv>(ID_subuv_motion, ii)));
	});
}

particle_mgr::quads_lists particle_mgr::sort_quads(){
	const int n = particlesystem_count(mmgr, ID_TAG_render_quad);
	if (n == 0){
		return std::move(quads_lists());
	}

	quads_lists	batchs(mmaterials.size());
	for (int ii=0; ii<n; ++ii){
		const auto material = sibling_component<particles::material>(ID_TAG_render_quad, ii);
		batchs[material->idx].push_front((uint16_t)ii);
	}

	return batchs;
}

void particle_mgr::submit_buffer(const quad_list &l){
	bgfx_transient_vertex_buffer_t tvb;
	mrenderdata.qb.alloc((uint32_t)l.size(), tvb);

	quaddata* quads = (quaddata*)tvb.data;

	for (auto iq : l){
		const auto scale		= sibling_component<particles::scale>(ID_TAG_render_quad, iq);
		const auto rotation		= sibling_component<particles::rotation>(ID_TAG_render_quad, iq);
		const auto translation	= sibling_component<particles::translation>(ID_TAG_render_quad, iq);

		glm::mat4 m = scale ? glm::scale(*scale) : glm::mat4(1.f);
		if (rotation)
			m = glm::mat4(*rotation) * m;

		if (translation)
			m = glm::translate(*translation) * m;

		//TODO: uv should move to another vertex buffer, if we not use uv, should not update
		quaddata& q = quads[iq];
		const auto &dq		= quaddata::default_quad();
		const auto quv		= sibling_component<particles::uv>(ID_TAG_render_quad, iq);
		const auto qsubuv	= sibling_component<particles::subuv>(ID_TAG_render_quad, iq);
		const auto qclr		= sibling_component<particles::color>(ID_TAG_render_quad, iq);

		const uint32_t c =	uint32_t(qclr->x >> 8)|
							uint32_t((qclr->y >>8)<<8)|
							uint32_t((qclr->z >>8)<<16)|
							uint32_t((qclr->w >>8)<<24);

		for (int ii=0; ii<4; ++ii){
			q[ii].p		= m * glm::vec4(dq[ii].p, 1.f);
			q[ii].uv	= quv->uv[ii];
			q[ii].subuv = qsubuv->uv[ii];
			q[ii].color = c;
		}
	}

	mrenderdata.qb.submit(tvb);
}

void
particle_mgr::submit_render(uint8_t materialidx){
	auto itmaterial = mmaterials.find(materialidx);
	if (itmaterial != mmaterials.end()){
		const auto &m = itmaterial->second;
		BGFX(set_state(m.state.state, m.state.rgba));

		for (const auto &[key, t] : m.properties.textures){
			BGFX(set_texture)(t.stage, {uint16_t(t.uniformid)}, {uint16_t(t.texid)}, UINT16_MAX);
		}

		for (const auto &[key, u] : m.properties.uniforms){
			BGFX(set_uniform)({uint16_t(u.uniformid)}, &u.value.x, 1);
		}
	
		BGFX(submit)(mrenderdata.viewid, {uint16_t(m.fx.prog)}, 0, BGFX_DISCARD_ALL);
	}
}

void
particle_mgr::submit(){
	auto batches = sort_quads();
	for (uint8_t materialidx=0; materialidx < batches.size(); ++materialidx){
		const auto &l = batches[materialidx];
		//TODO: need instance draw
		submit_buffer(l);
		submit_render(materialidx);
	}
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

	submit();
}