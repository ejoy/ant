#include "pch.h"
#include "particle.h"
#include "transforms.h"
#include "quadcache.h"

#include "random.h"
#include <sstream>
#include <Windows.h>

#define PARTICLE_COMPONENT		ID_count
#define PARTICLE_KEY_COMPONENT	ID_key_count
#include "psystem_manager.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

#ifdef _DEBUG
const char* g_component_names[ID_count] = {
	"ID_life = 0",
	"ID_spawn",
	"ID_velocity",
	"ID_acceleration",
	"ID_transform",
	"ID_quad",
	"ID_uv_motion",

	"ID_init_life_interpolator",
	"ID_init_spawn_interpolator",
	"ID_init_velocity_interpolator",
	"ID_init_acceleration_interpolator",
	"ID_init_render_interpolator",
	"ID_init_uv_motion_interpolator",
	"ID_init_quad_interpolator",

	"ID_lifetime_life_interpolator",
	"ID_lifetime_spawn_interpolator",
	"ID_lifetime_velocity_interpolator",
	"ID_lifetime_acceleration_interpolator",
	"ID_lifetime_render_interpolator",
	"ID_lifetime_uv_motion_interpolator",
	"ID_lifetime_quad_interpolator",

	"ID_key_count",

	"ID_TAG_emitter",
	"ID_TAG_uv_motion",
	"ID_TAG_uv",
	"ID_TAG_scale",
	"ID_TAG_rotation",
	"ID_TAG_translate",
	"ID_TAG_render_quad",
	"ID_TAG_material",
	"ID_TAG_color",
};

static inline const char*
component_id_name(component_id id) { return g_component_names[id]; }

// void
// particle_mgr::debug_print_particle_component(int idx){

// }

// void
// particle_mgr::debug_print_remap(struct particle_remap* remp, int n){

// }
#endif

particle_mgr::particle_mgr()
    : mmgr(particlesystem_create()){

	create_array<particles::life>();
	create_array<particles::spawn>();
	create_array<particles::velocity>();
	create_array<particles::acceleration>();
	create_array<particles::transform>();
	create_array<particles::uv_motion>();
	create_array<particles::quad>();

	create_array<particles::init_life_interpolator>();
	create_array<particles::init_spawn_interpolator>();
	create_array<particles::init_velocity_interpolator>();
	create_array<particles::init_acceleration_interpolator>();
	create_array<particles::init_transform_interpolator>();
	create_array<particles::init_quad_interpolator>();
	
	create_array<particles::lifetime_life_interpolator>();
	create_array<particles::lifetime_spawn_interpolator>();
	create_array<particles::lifetime_velocity_interpolator>();
	create_array<particles::lifetime_acceleration_interpolator>();
	create_array<particles::lifetime_transform_interpolator>();
	create_array<particles::lifetime_quad_interpolator>();
}

class component_array {
public:
	virtual ~component_array() = default;
	virtual int remap(struct particle_remap* map, int n) = 0;
	virtual void pop_back() = 0;
};

particle_mgr::~particle_mgr(){
    particlesystem_release(mmgr);

	for(auto &a : mcomp_arrays){
		delete a;
		a = nullptr;
	}
}

template<typename T>
class component_array_baseT : public component_array {
public:
	component_id add(T &&v){
		mdata.push_back(std::move(v));
		return T::ID;
	}

	std::vector<T> mdata;

	virtual int remap(struct particle_remap* map, int n) override;
};

template<typename T>
class component_arrayT : public component_array_baseT<T> {
public:
	virtual ~component_arrayT() = default;
	void move(int from, int to){
		this->mdata[from] = this->mdata[to];
	}

	void shrink(int n) {
		this->mdata.resize(n);
	}

	virtual void pop_back() override{
		this->mdata.pop_back();
	}
};

template<typename T>
class component_arrayT<T*> : public component_array_baseT<T*>{
public:
	virtual ~component_arrayT(){
		for (auto &p : this->mdata){
			delete p;
		}
	}

	void move(int from, int to) {
		delete this->mdata[to];
		this->mdata[to] = this->mdata[from];
		this->mdata[from] = nullptr;
	}

	void shrink(int n) {
		for (int ii=n; ii<this->mdata.size(); ++ii){
			delete this->mdata[ii];
		}
		this->mdata.resize(n);
	}

	virtual void pop_back() override{
		delete this->mdata.back();
		this->mdata.pop_back();
	}
};


template<typename T>
int component_array_baseT<T>::remap(struct particle_remap *map, int n) {
	for (int i=0;i<n;i++) {
		if (map[i].component_id != map[0].component_id)
			return i;

		auto self = static_cast<component_arrayT<T>*>(this);
		if (map[i].to_id != PARTICLE_INVALID) {
			self->move(map[i].from_id, map[i].to_id);
		} else {
			self->shrink(map[i].from_id);
		}
	}
	return n;
}

template<typename T>
void particle_mgr::create_array(){
	using TT = typename std::remove_pointer<T>::type;
	mcomp_arrays[TT::ID()] = new component_arrayT<T>();
}

static inline bool
is_const_interp(int type){
	return type == 0;
}

static inline bool
is_linear_interp(int type){
	return type == 1;
}

static inline bool
is_curve_interp(int type){
	return type > 1;
}

template<typename T>
std::vector<T>& particle_mgr::data(){
	return static_cast<component_arrayT<T>*>(mcomp_arrays[T::ID()])->mdata;
}

template<typename VALUE_TYPE>
static void
interp_vec(const VALUE_TYPE &scale, int type, randomobj &ro, VALUE_TYPE &v){
	if (is_linear_interp(type)){
		for (uint32_t ii=0; ii<(uint32_t)scale.length(); ++ii){
			v[ii] = scale[ii] * particles::lifedata::MAX_PROCESS;
			const float random = ro();
			v[ii] *= random;
		}
	} else if (is_const_interp(type)){
		for (uint32_t ii=0; ii<(uint32_t)scale.length(); ++ii){
			v[ii] = scale[ii] * particles::lifedata::MAX_PROCESS;
		}
	}
}

static uint32_t
interp_color(const glm::vec4 &scale, int type, randomobj &ro){
	glm::vec4 v(0);
	interp_vec(scale, type, ro, v);
	v *= 255.f;
	return uint32_t(uint8_t(v[0]) << 0|uint8_t(v[1]) << 8|uint8_t(v[2]) << 16 |uint8_t(v[3]) <<24);
}

void
particle_mgr::spawn_particles(uint32_t spawnnum, uint32_t spawnidx, const particles::spawndata &sd){
	if (spawnnum == 0 || spawnnum > sd.count){
		return ;
	}

	struct spawn_id{
		component_id id;
		particle_index idx;
	};

	std::vector<spawn_id>	particle_indices;

	//TODO: should be gloabl value
	std::unordered_map<component_id, std::function<void (uint32_t, randomobj &, comp_ids&)>>	create_component_ops = {
		std::make_pair(ID_init_life_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &init_life_interpolator = data<particles::init_life_interpolator>();
			const auto& interp_life = init_life_interpolator[idx];

			float life = interp_life.scale * particles::lifedata::MAX_PROCESS;
			if (is_linear_interp(interp_life.type))
				life *= ro();
			ids.push_back(add_component(particles::life{particles::lifedata(life)}));
		}),

		std::make_pair(ID_init_velocity_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids ){
			const auto &c = data<particles::init_velocity_interpolator>()[idx];
			particles::velocity v; interp_vec(c.scale, c.type, ro, *(glm::vec3*)&v);
			ids.push_back(add_component(v));
		}),

		std::make_pair(ID_init_acceleration_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &c = data<particles::init_acceleration_interpolator>()[idx];
			particles::acceleration a; interp_vec(c.scale, c.type, ro, *(glm::vec3*)&a);
			ids.push_back(add_component(a));
		}),

		std::make_pair(ID_init_render_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &ri = data<particles::init_transform_interpolator>()[idx];
			particles::transform rd;
			interp_vec(ri.s.scale, ri.s.type, ro, rd.s);
			interp_vec(ri.t.scale, ri.t.type, ro, rd.t);
			ids.push_back(add_component(rd));
			ids.push_back(ID_TAG_render_quad);
			
		}),
		std::make_pair(ID_init_quad_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids &ids){
			const auto &qi = data<particles::init_quad_interpolator>()[idx];
			const auto clr = interp_color(qi.color.scale, qi.color.type, ro);
			particles::quad q;
			for(uint32_t ii=0; ii<4; ++ii){
				const auto &uv = qi.uv[ii];
				auto& v = q[ii];
				v.color = clr;
				interp_vec(uv.scale, uv.type, ro, v.uv);
			}

			ids.push_back(add_component(q));
		}),
		std::make_pair(ID_uv_motion, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &uvm = data<particles::uv_motion>()[idx];
			ids.push_back(add_component(uvm));
			ids.push_back(ID_TAG_uv_motion);
		}),
	};

	for (int ii=ID_life; ii<ID_key_count; ++ii){
		const auto initid = component_id(ii);
		const particle_index idx = particlesystem_component(mmgr, ID_TAG_emitter, spawnidx, initid);
		if (PARTICLE_INVALID != idx)
			particle_indices.push_back(spawn_id{initid, idx});
	}

	randomobj ro;
	for (uint32_t ii=0; ii<spawnnum; ++ii){
		comp_ids ids;
		for (auto p : particle_indices){
			auto it = create_component_ops.find(p.id);
			if (it != create_component_ops.end()){
				it->second(p.idx, ro, ids);
			}
		}
	
		add(ids);
	}
}

bool particle_mgr::add(const comp_ids &ids){
	const bool valid = 0 != particlesystem_add(mmgr, (int)ids.size(), (const int*)(&ids.front()));
	if (!valid)
		pop_back(ids);
	return valid;
}

void
particle_mgr::pop_back(const comp_ids &ids){
	for(auto id : ids){
		mcomp_arrays[id]->pop_back();
	}
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
		if (c.update_process()){
			remove_particle((uint32_t)ii);
		}
    }
}

void
particle_mgr::update_particle_spawn(float dt){
	const int n = particlesystem_count(mmgr, ID_TAG_emitter);
	const auto &spawns = data<particles::spawn>();
	const auto &lifes = data<particles::life>();

	const uint32_t deltatick = particles::lifedata::time2tick(dt);
	for (int ii=0; ii<n; ++ii){
		const auto &sp = spawns[ii];
		const auto idx = particlesystem_component(mmgr, ID_TAG_emitter, ii, ID_spawn);
		const auto lidx = particlesystem_component(mmgr, ID_TAG_emitter, ii, ID_life);

		const auto& l = lifes[lidx];
		const uint32_t spawnnum = uint32_t((deltatick / float(l.tick)) * sp.count);
		spawn_particles(spawnnum, idx, sp);
	}
}

void
particle_mgr::update_velocity(float dt){
	const auto &acc = data<particles::acceleration>();
	auto &vel = data<particles::velocity>();
	for (size_t aidx=0; aidx<acc.size(); ++aidx){
		const auto &a = acc[aidx];
		auto vidx = particlesystem_component(mmgr, ID_acceleration, (particle_index)aidx, ID_velocity);
		assert(vidx < vel.size());
		auto &v = vel[vidx];
		v += a * dt;
	}
}

void
particle_mgr::update_translation(float dt){
	const auto &vel = data<particles::velocity>();
	auto &render = data<particles::transform>();

	for (size_t vidx=0; vidx<vel.size(); ++vidx){
		const auto &v = vel[vidx];
		auto tidx = particlesystem_component(mmgr, ID_velocity, (particle_index)vidx, ID_transform);
		if (tidx != PARTICLE_INVALID){
			auto &r = render[vidx];
			r.t += v * dt;
		}
	}
}

void
particle_mgr::update_uv_motion(float dt){
	const auto &uvmotion = data<particles::uv_motion>();
	auto &quads = data<particles::quad>();

	const int n = particlesystem_count(mmgr, ID_TAG_uv_motion);

	for(int pidx=0; pidx<n; ++pidx){
		const auto uvm_idx = particlesystem_component(mmgr, ID_TAG_uv_motion, pidx, ID_uv_motion);
		const auto qidx = particlesystem_component(mmgr, ID_TAG_uv_motion, pidx, ID_quad);
		const auto &uvm = uvmotion[uvm_idx];

		auto &q = quads[qidx];
	
		for (int ii=0; ii<4; ++ii){
			auto& v = q[ii];
			v.uv.x += dt * uvm.u_speed * uvm.scale;
			v.uv.y += dt * uvm.v_speed * uvm.scale;
		}
	}
}

void
particle_mgr::update_quad_transform(float dt){
	auto& quads = data<particles::quad>();
	const auto& renders = data<particles::transform>();

	for (int iq = 0; iq < renders.size(); ++iq) {
		auto& q = quads[iq];
		const int ir = particlesystem_component(mmgr, ID_quad, iq, ID_transform);
		const auto &r = renders[ir];

		glm::mat4 m = glm::scale(r.s);
		m = glm::mat4(r.r) * m;
		m = glm::translate(r.t) * m;
		quad_cache::transform(q, m);
	}
}

void submit_buffer(uint32_t num, const quaddata* qv, bgfx_index_buffer_handle_t ibhandle, const bgfx_vertex_layout_t *layout);

void particle_mgr::submit_buffer(){
	const auto &quads = data<particles::quad>();
	if (!quads.empty())
		::submit_buffer((uint32_t)quads.size(), &quads[0], bgfx_index_buffer_handle_t{mrenderdata.ibhandle}, mrenderdata.layout);
}

void
particle_mgr::submit_render(){
	//mqc->update();
	//mqc->submit(0, (uint32_t)data<particles::transform>().size()); 
	BGFX(set_state(uint64_t(BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA), 0));
	submit_buffer();

	for (size_t ii=0; ii<mrenderdata.textures.size(); ++ii){
		const auto &t = mrenderdata.textures[ii];
		BGFX(set_texture)((uint8_t)ii, {t.uniformid}, {t.texid}, UINT16_MAX);
	}
	
	BGFX(submit)(mrenderdata.viewid, {mrenderdata.progid}, 0, BGFX_DISCARD_ALL);
}

void
particle_mgr::remap_particles(){
    struct particle_remap remap[128];
	struct particle_arrange_context ctx;
	int cap = sizeof(remap)/sizeof(remap[0]);
	int n;
	do {
		n = particlesystem_arrange(mmgr, cap, remap, &ctx);
		int i = 0;
		while (i < n) {
			int id = remap[i].component_id;
			if (id < ID_key_count) {
				i += mcomp_arrays[id]->remap(remap + i, n - i);
			} else {
				++i;
			}
		}
	} while (n == cap);
}

void
particle_mgr::update(float dt){
	update_particle_spawn(dt);
	update_velocity(dt);
	update_translation(dt);
	update_uv_motion(dt);

	update_quad_transform(dt);

	update_lifetime(dt);	// should be last update
	remap_particles();

	//TODO: we can fully control render in lua level, only need vertex buffer in quad_cache
	submit_render();
}
