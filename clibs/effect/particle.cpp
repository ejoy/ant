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
	"ID_life",
	"ID_spawn",
	"ID_velocity",
	"ID_acceleration",
	"ID_scale",
	"ID_rotation",
	"ID_translation",
	"ID_uv_motion",
	"ID_quad",
	"ID_material",

	"ID_key_count",

	"ID_velocity_interpolator",
	"ID_acceleration_interpolator",
	"ID_scale_interpolator",
	"ID_rotation_interpolator",
	"ID_translation_interpolator",
	"ID_uv_motion_interpolator",
	"ID_color_interpolator",

	"ID_component_count",

	"ID_TAG_emitter",
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
	create_array<particles::scale>();
	create_array<particles::rotation>();
	create_array<particles::translation>();
	create_array<particles::uv_motion>();
	create_array<particles::quad>();
	create_array<particles::material>();
	
	create_array<particles::velocity_interpolator>();
	create_array<particles::acceleration_interpolator>();
	create_array<particles::scale_interpolator>();
	//create_array<particles::rotation_interpolator>();
	create_array<particles::translation_interpolator>();
	create_array<particles::color_interpolator>();
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

		debug_print(g_component_names[map[i].component_id]);
		auto self = static_cast<component_arrayT<T>*>(this);
		if (map[i].to_id != PARTICLE_INVALID) {
			debug_print("move:", map[i].from_id, map[i].to_id);
			self->move(map[i].from_id, map[i].to_id);
		} else {
			debug_print("resize:", map[i].from_id);
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

template<typename T>
std::vector<T>& particle_mgr::data(){
	return static_cast<component_arrayT<T>*>(mcomp_arrays[T::ID()])->mdata;
}

static void
check_add_id(comp_ids &ids, component_id id){
	assert(std::find(ids.begin(), ids.end(), id) == ids.end());
	ids.push_back(id);
}

std::unordered_map<component_id, std::function<void (const particles::spawn&, randomobj &, comp_ids &)>> g_spwan_operations = {
	std::make_pair(ID_life, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::life(spawn.init.life.get(ro()))
		));
	}),
	std::make_pair(ID_velocity, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::velocity(spawn.init.velocity.get(ro()))
		));
	}),
	std::make_pair(ID_acceleration, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::acceleration(spawn.init.acceleration.get(ro()))
		));
	}),
	std::make_pair(ID_scale, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::scale(spawn.init.scale.get(ro()))
		));
	}),
	std::make_pair(ID_rotation, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		// check_add_id(ids, particle_mgr::get().add_component(
		// 	particles::scale(spawn.init.scale.get(ro()))
		// ));
	}),
	std::make_pair(ID_translation, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::translation(spawn.init.scale.get(ro()))
		));
	}),
	std::make_pair(ID_uv_motion, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(
			particles::uv_motion(spawn.init.uv_motion.get(ro()))
		));
	}),
	std::make_pair(ID_quad, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		particles::quad q;
		uint32_t color = 0;
		uint8_t *rgba = (uint8_t*)&color;
		for(int ii=0; ii<4;++ii){
			rgba[ii] = to_color_channel(spawn.init.color.rgba[ii].get(ro()));
		}
		for (int ii=0; ii<4; ++ii){
			q[ii].color = color;
		}
		check_add_id(ids, particle_mgr::get().add_component(q));
		check_add_id(ids, ID_TAG_render_quad);
	}),
	std::make_pair(ID_material, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		check_add_id(ids, particle_mgr::get().add_component(particles::material(spawn.init.material)));
	}),
	std::make_pair(ID_velocity_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_velocity) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::velocity(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::velocity_interpolator(spawn.interp.velocity)
		));
	}),
	std::make_pair(ID_acceleration_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_acceleration) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::acceleration(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::acceleration_interpolator(spawn.interp.acceleration)
		));
	}),
	std::make_pair(ID_scale_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_scale) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::scale(1.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::scale_interpolator(spawn.interp.scale)
		));
	}),
	std::make_pair(ID_rotation_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		// if (std::find(ids.begin(), ids.end(), ID_rotation) != ids.end()){
		// 	check_add_id(ids, particle_mgr::get().add_component(particles::rotation(0.f)));
		// }
		// check_add_id(ids, particle_mgr::get().add_component(
		// 	particles::rotation_interpolator(spawn.interp.rotation)
		// ));
	}),
	std::make_pair(ID_translation_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_translation) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::translation(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::translation_interpolator(spawn.interp.translation)
		));
	}),
		std::make_pair(ID_uv_motion_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_uv_motion) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::uv_motion(0.f)));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::uv_motion_interpolator(spawn.interp.uv_motion)
		));
	}),
	std::make_pair(ID_color_interpolator, [](const particles::spawn& spawn, randomobj &ro, comp_ids &ids){
		if (std::find(ids.begin(), ids.end(), ID_quad) == ids.end()){
			check_add_id(ids, particle_mgr::get().add_component(particles::quad()));
		}
		check_add_id(ids, particle_mgr::get().add_component(
			particles::color_interpolator(spawn.interp.color)
		));
	}),
};

void
particle_mgr::spawn_particles(uint32_t spawnnum, uint32_t spawnidx, const particles::spawn &sd){
	debug_print("spawn:", spawnnum);
	if (spawnnum == 0 || spawnnum > sd.count){
		return ;
	}

	randomobj ro;

	for (uint32_t ii=0; ii<spawnnum; ++ii){
		comp_ids ids;
		for (auto id : sd.init.components)
			g_spwan_operations[id](sd, ro, ids);
		for (auto id : sd.interp.components)
			g_spwan_operations[id](sd, ro, ids);

		add(ids);
	}
}

bool particle_mgr::add(const comp_ids &ids){
	#ifdef _DEBUG
	int checkids[ID_count] = {0};
	for (auto id:ids){
		++checkids[id];
		if (checkids[id] > 1){
			assert(false && "dup id");
		}
	}
	#endif //_DEBUG

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
	debug_print("remove:", pidx);
	particlesystem_remove(mmgr, ID_life, (particle_index)pidx);
}

void
particle_mgr::update_lifetime(float dt){
	auto &lifes = data<particles::life>();
	for (size_t ii=0; ii<lifes.size(); ++ii){
		auto &c = lifes[ii];
		c.current += dt;
		debug_print("life:", ii, c.current, c.process, c.tick);
		if (c.update_process()){
			debug_print("remove:", ii);
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
	auto &translations = data<particles::translation>();

	for (size_t vidx=0; vidx<vel.size(); ++vidx){
		const auto &v = vel[vidx];
		auto tidx = particlesystem_component(mmgr, ID_velocity, (particle_index)vidx, ID_translation);
		if (tidx != PARTICLE_INVALID){
			auto &t = translations[vidx];
			t += v * dt;
		}
	}
}

void
particle_mgr::update_lifetime_scale(float dt){
	const auto &scale_interpolators = data<particles::scale_interpolator>();
	const auto &lifes = data<particles::life>();
	auto &scales = data<particles::scale>();

	for (int ii=0; ii<(int)scale_interpolators.size(); ++ii){
		// transform
		const auto ilife = particlesystem_component(mmgr, ID_scale_interpolator, ii, ID_life);
		assert(ilife != PARTICLE_INVALID);
		const auto& life = lifes[ilife];

		const auto iscale = particlesystem_component(mmgr, ID_scale_interpolator, ii, ID_scale);
		assert(iscale != PARTICLE_INVALID);
		auto& scale = scales[iscale];

		auto &si = scale_interpolators[ii];
		scale = si.get(scale, life.delta_process(dt));
	}
}

void
particle_mgr::update_lifetime_rotation(float dt){

}

void
particle_mgr::update_lifetime_color(float dt){
	const auto &lifes = data<particles::life>();
	const auto &color_interpolators = data<particles::color_interpolator>();
	auto &quads = data<particles::quad>();

	for(int ii=0; ii<(int)color_interpolators.size(); ++ii){
		const auto quad_idx = particlesystem_component(mmgr, ID_color_interpolator, ii, ID_quad);
		assert(quad_idx != PARTICLE_INVALID);
		auto& q = quads[quad_idx];

		const auto ilife	= particlesystem_component(mmgr, ID_color_interpolator, ii, ID_life);
		assert(quad_idx != PARTICLE_INVALID);
		const auto& life = lifes[ilife];

		const auto& ci = color_interpolators[ii];
		for (int iv = 0; iv < 4; ++iv) {
			uint8_t* rgba = (uint8_t*)(&q[iv].color);
			for (int ii = 0; ii < 4; ++ii) {
				const auto& c = ci.rgba[ii];
				rgba[ii] = to_color_channel(c.get(to_color_channel(rgba[ii]), life.delta_process(dt)));
			}
		}
	}
}

void
particle_mgr::update_uv_motion(float dt){
	const auto &uvmotions = data<particles::uv_motion>();
	auto &quads = data<particles::quad>();

	for (int ii=0; ii<(int)uvmotions.size(); ++ii){
		const auto qidx = particlesystem_component(mmgr, ID_uv_motion, ii, ID_quad);
		assert(qidx != PARTICLE_INVALID);
		auto &q = quads[qidx];

		const auto &uvm = uvmotions[ii];
		for (int ii=0; ii<4; ++ii){
			q[ii].uv = dt * uvm;
		}
	}
}

void
particle_mgr::update_quad_transform(float dt){
	auto& quads = data<particles::quad>();
	const auto& scales = data<particles::scale>();
	const auto& rotations = data<particles::rotation>();
	const auto& translations = data<particles::translation>();

	for (int iq = 0; iq < (int)quads.size(); ++iq) {
		quaddata* q = &quads[iq];

		const auto is = particlesystem_component(mmgr, ID_quad, iq, ID_scale);
		const auto ir = particlesystem_component(mmgr, ID_quad, iq, ID_rotation);
		const auto it = particlesystem_component(mmgr, ID_quad, iq, ID_translation);
		if (is == PARTICLE_INVALID && ir == PARTICLE_INVALID && it == PARTICLE_INVALID)
			continue;

		glm::mat4 m = (is != PARTICLE_INVALID) ? glm::scale(scales[is]) : glm::mat4(1.f);
		if (ir != PARTICLE_INVALID)
			m = glm::mat4(rotations[ir]) * m;
	
		if (it != PARTICLE_INVALID)
			m = glm::translate(translations[it]) * m;

		*q = quaddata::default_quad();
		q->transform(m);
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
