#include "pch.h"
#include "particle.h"
#include "transforms.h"
#include "quadcache.h"

#include "random.h"
#include <sstream>
#include <Windows.h>

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
    "ID_material",

    "ID_init_life_interpolator",
    "ID_init_spawn_interpolator",
    "ID_init_velocity_interpolator",
    "ID_init_acceleration_interpolator",
    "ID_init_transform_interpolator",
    "ID_init_uv_motion_interpolator",
    "ID_init_quad_interpolator",

    "ID_lifetime_life_interpolator",
    "ID_lifetime_spawn_interpolator",
    "ID_lifetime_velocity_interpolator",
    "ID_lifetime_acceleration_interpolator",
    "ID_lifetime_transform_interpolator",
    "ID_lifetime_uv_motion_interpolator",
    "ID_lifetime_quad_interpolator",

    "ID_key_count",
    "ID_TAG_emitter",
    "ID_TAG_uv_motion",
    "ID_TAG_uv",
    "ID_TAG_color",
    "ID_TAG_scale",
    "ID_TAG_rotation",
    "ID_TAG_translate",
    "ID_TAG_render_quad",
    "ID_TAG_material",
};

static_assert(ID_count == sizeof(g_component_names)/sizeof(g_component_names[0]));

static inline const char*
component_id_name(component_id id) { return g_component_names[id]; }

static void
debug_print2(std::ostringstream &oss){
	oss << std::endl;
	OutputDebugStringA(oss.str().c_str());
}

template<typename T, typename ...Args>
static void
debug_print2(std::ostringstream &oss, const T &t, Args... args){
	oss << t << "\t";
	debug_print2(oss, args...);
}

template<typename ...Args>
static void
debug_print(Args... args){
	std::ostringstream oss;
	debug_print2(oss, args...);
}

#define PARTICLE_COMPONENT		ID_count
#define PARTICLE_KEY_COMPONENT	ID_key_count
#define printf debug_print
#include "psystem_manager.h"
#undef printf
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
	create_array<particles::init_uv_motion_interpolator>();
	
	create_array<particles::lifetime_life_interpolator>();
	create_array<particles::lifetime_spawn_interpolator>();
	create_array<particles::lifetime_velocity_interpolator>();
	create_array<particles::lifetime_acceleration_interpolator>();
	create_array<particles::lifetime_transform_interpolator>();
	create_array<particles::lifetime_quad_interpolator>();
	create_array<particles::lifetime_uv_motion_interpolator>();
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

namespace interpolation {
static inline bool
is_const(int type){
	return type == 0;
}

static inline bool
is_linear(int type){
	return type == 1;
}

static inline bool
is_curve(int type){
	return 1 < type && type < UINT8_MAX;
}

static inline bool
is_valid(int type){
	return type == UINT8_MAX;
}

static inline void
random_float(float scale, int type, randomobj &ro, float &v){
	v = scale * particles::lifedata::MAX_PROCESS;
	if (is_linear(type))
		v *= ro();
}

template<typename VALUE_TYPE>
static void
random_vec(const VALUE_TYPE &scale, int type, randomobj &ro, VALUE_TYPE &v){
	if (is_linear(type)){
		for (uint32_t ii=0; ii<(uint32_t)scale.length(); ++ii){
			v[ii] = scale[ii] * particles::lifedata::MAX_PROCESS;
			const float random = ro();
			v[ii] *= random;
		}
	} else if (is_const(type)){
		const float inv = 1.f / particles::lifedata::MAX_PROCESS;
		v = scale * inv;
	}
}

static inline void
random_color(const particles::color_interp_value& civ, randomobj &ro, uint32_t &clr){
	glm::vec4 v(0);
	for (int ii=0; ii<4; ++ii){
		random_float(civ.rgba[ii].scale, civ.rgba[ii].type, ro, v[ii]);
	}
	
	clr = uint32_t( uint8_t(v[0])<<0|
					uint8_t(v[1])<<8|
					uint8_t(v[2])<<16|
					uint8_t(v[3])<<24);
}

template<typename VALUE_TYPE>
static void
interp(const VALUE_TYPE &scale, int type, uint32_t process, VALUE_TYPE &v){
	if (is_const(type))
		return;

	if (is_linear(type)){
		v = float(process) * scale;
		return;
	}

	assert(false);
}

}


template<typename T>
std::vector<T>& particle_mgr::data(){
	return static_cast<component_arrayT<T>*>(mcomp_arrays[T::ID()])->mdata;
}

void
particle_mgr::spawn_particles(uint32_t spawnnum, uint32_t spawnidx, const particles::spawndata &sd){
	debug_print("spawn:", spawnnum);
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
			const auto &interp_life = data<particles::init_life_interpolator>()[idx];
			float life;
			interpolation::random_float(interp_life.scale, interp_life.type, ro, life);
			particles::life l; l.set(life);
			ids.push_back(add_component(l));
		}),

		std::make_pair(ID_init_velocity_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids ){
			const auto &c = data<particles::init_velocity_interpolator>()[idx];
			particles::velocity v; interpolation::random_vec(c.scale, c.type, ro, *(glm::vec3*)&v);
			ids.push_back(add_component(v));
		}),

		std::make_pair(ID_init_acceleration_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &c = data<particles::init_acceleration_interpolator>()[idx];
			particles::acceleration a; interpolation::random_vec(c.scale, c.type, ro, *(glm::vec3*)&a);
			ids.push_back(add_component(a));
		}),
		std::make_pair(ID_init_transform_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &ti = data<particles::init_transform_interpolator>()[idx];
			particles::transform rd;
			interpolation::random_vec(ti.s.scale, ti.s.type, ro, rd.s);
			interpolation::random_vec(ti.t.scale, ti.t.type, ro, rd.t);
			ids.push_back(add_component(rd));
		}),
		std::make_pair(ID_lifetime_transform_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &t = data<particles::lifetime_transform_interpolator>()[idx];
			ids.push_back(add_component(t));
			if (interpolation::is_valid(t.s.type)){
				ids.push_back(ID_TAG_scale);
			}

			if (interpolation::is_valid(t.r.type)){
				ids.push_back(ID_TAG_rotation);
			}
		}),
		std::make_pair(ID_init_quad_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids &ids){
			const auto &qi = data<particles::init_quad_interpolator>()[idx];
			particles::quad q;
			uint32_t clr;
			interpolation::random_color(qi.color, ro, clr);
			for (int ii=0; ii<4; ++ii)
				q[ii].color = clr;

			ids.push_back(add_component(q));
			ids.push_back(ID_TAG_render_quad);
		}),
		std::make_pair(ID_lifetime_quad_interpolator, [this](uint32_t idx, randomobj &ro, comp_ids& ids){
			const auto &lqi = data<particles::lifetime_quad_interpolator>()[idx];
			ids.push_back(add_component(lqi));
			ids.push_back(ID_TAG_color);
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
	const int n = particlesystem_count(mmgr, ID_TAG_emitter);
	for (int ii=0; ii<n; ++ii){
		const int idx = particlesystem_component(mmgr, ID_TAG_emitter, ii, ID_life);
		if (pidx == idx){
			debug_print("remove emitter");
		}
	}

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
		const uint32_t tick_prerate = particles::lifedata::time2tick(sp.rate);
		
		const auto idx = particlesystem_component(mmgr, ID_TAG_emitter, ii, ID_spawn);
		const auto lidx = particlesystem_component(mmgr, ID_TAG_emitter, ii, ID_life);

		const auto& l = lifes[lidx];
		const uint32_t spawnnum = uint32_t((deltatick / float(tick_prerate)) * sp.count);
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
	auto &trans = data<particles::transform>();

	for (size_t vidx=0; vidx<vel.size(); ++vidx){
		const auto &v = vel[vidx];
		auto tidx = particlesystem_component(mmgr, ID_velocity, (particle_index)vidx, ID_transform);
		if (tidx != PARTICLE_INVALID){
			auto &r = trans[vidx];
			r.t += v * dt;
		}
	}
}

void
particle_mgr::update_lifetime_scale(float dt){
	const auto &trans_interp = data<particles::lifetime_transform_interpolator>();
	const auto &lifes = data<particles::life>();
	auto &trans = data<particles::transform>();
	
	const int n = particlesystem_count(mmgr, ID_TAG_scale);
	for (int ii=0; ii<n; ++ii){
		// transform
		const auto itrans = particlesystem_component(mmgr, ID_TAG_scale, ii, ID_lifetime_transform_interpolator);
		if (itrans != PARTICLE_INVALID){
			auto &ti = trans_interp[itrans];
			
			const auto trans_idx = particlesystem_component(mmgr, ID_TAG_scale, ii, ID_transform);
			const auto life_idx = particlesystem_component(mmgr, ID_TAG_scale, ii, ID_life);
			const auto& life = lifes[life_idx];

			auto &t = trans[trans_idx];
			glm::vec3 s(1.f);
			interpolation::interp(ti.s.scale, ti.s.type, life.process, s);
			t.s *= s;
		}
	}
}

void
particle_mgr::update_lifetime_rotation(float dt){

}

void
particle_mgr::update_lifetime_color(float dt){
	const auto &lifes = data<particles::life>();
	const auto &quad_interp = data<particles::lifetime_quad_interpolator>();
	auto &quads = data<particles::quad>();

	const int n = particlesystem_count(mmgr, ID_TAG_color);
	for(int ii=0; ii<n; ++ii){
		const auto quad_idx 		= particlesystem_component(mmgr, ID_TAG_color, ii, ID_quad);
		auto &q = quads[quad_idx];

		const auto quad_interp_idx	= particlesystem_component(mmgr, ID_TAG_color, ii, ID_lifetime_quad_interpolator);
		const auto &qi = quad_interp[quad_interp_idx];

		const auto life_idx			= particlesystem_component(mmgr, ID_TAG_color, ii, ID_life);
		const auto &life = lifes[life_idx];

		for (int ic=0; ic<4; ++ic){
			const auto &c = qi.color.rgba[ic];
			float v = 0.f;
			interpolation::interp(c.scale, c.type, life.process, v);
			const uint8_t channel = to_color_channel(v);

			for (int iv=0; iv<4; ++iv){
				uint8_t* rgba = (uint8_t*)(&(q[iv].color));
				const uint16_t nc = uint16_t(channel) * rgba[ic];
				rgba[ic] = uint8_t(std::min(uint16_t(UINT8_MAX), nc));
			}
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
			q[ii].uv = dt * glm::vec2(uvm.u_speed, uvm.v_speed) * uvm.scale;
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
		q.transform(m);
	}
}

void particle_mgr::submit_buffer(){
	const auto& quads = data<particles::quad>();
	static_assert(sizeof(decltype(quads)) == sizeof(quadvector));
	const quadvector* qv = (quadvector*)&quads;
	mrenderdata.qb.submit(*qv);
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
particle_mgr::print_particles_status(){
	// return;
	// const auto &lifes = data<particles::life>();
	// struct particle_info {
	// 	struct pair{
	// 		component_id id;
	// 		int pidx;
	// 	};
	// 	std::vector<pair>	comps;
	// };
	// using particles_info_vector = std::vector<particle_info>;
	// particles_info_vector pis;
	// for (int ii=0; ii<lifes.size(); ++ii){
	// 	particle_info pi;
	// 	for (int idx=0; idx<ID_key_count; ++idx){
	// 		const component_id id = (component_id)idx;
	// 		const auto pidx = particlesystem_component(mmgr, ID_life, ii, id);
	// 		if (pidx != PARTICLE_INVALID){
	// 			pi.comps.push_back({id, pidx});
	// 		}
	// 	}
	// }

	// for (int ii=0; ii<pis.size(); ++ii){
	// 	debug_print("particle:", ii);
	// 	const auto &pi = pis[ii];
	// 	for (int id=0; id<pi.comps.size(); ++ii){
	// 		debug_print("\tcomponent:", g_component_names[id], "\tisdead:", lifes[ii].isdead());
	// 	}
	// }
	particlesystem_debug(mmgr, g_component_names);
}

void
particle_mgr::update(float dt){
	update_particle_spawn(dt);
	//print_particles_status();
	update_velocity(dt);
	update_translation(dt);
	update_uv_motion(dt);
	update_lifetime_color(dt);
	update_lifetime_scale(dt);

	update_quad_transform(dt);
	update_lifetime(dt);	// should be last update
	remap_particles();
	assert(0 == particlesystem_verify(mmgr));
	//print_particles_status();
	//TODO: we can fully control render in lua level, only need vertex buffer in quad_cache
	submit_render();
}
