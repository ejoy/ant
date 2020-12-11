#include "pch.h"
#include "particle.h"
#include "quadcache.h"

#include "random.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

#ifdef _DEBUG
#include <sstream>
#include <Windows.h>
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

	"ID_velocity_interpolator",
	"ID_acceleration_interpolator",
	"ID_scale_interpolator",
	"ID_rotation_interpolator",
	"ID_translation_interpolator",
	"ID_uv_motion_interpolator",
	"ID_color_interpolator",

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
#define PARTICLE_TAGS			(ID_count - ID_component_count)
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

template<typename T>
std::vector<T>& particle_mgr::data(){
	return static_cast<component_arrayT<T>*>(mcomp_arrays[T::ID()])->mdata;
}

template<typename T>
T* particle_mgr::sibling_component(component_id id, int ii){
	const auto idx = particlesystem_component(mmgr, id, ii, T::ID());
	return (idx != PARTICLE_INVALID) ? &(data<T>()[idx]) : nullptr;
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
particle_mgr::spawn_particles(uint32_t spawnnum, const particles::spawn &sd){
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
		if (c.update_process()){
			remove_particle((uint32_t)ii);
		}
    }
}

void
particle_mgr::update_particle_spawn(float dt){
	const int n = particlesystem_count(mmgr, ID_TAG_emitter);
	const auto &spawns = data<particles::spawn>();

	const uint32_t deltatick = particles::lifedata::time2tick(dt);
	for (int ii=0; ii<n; ++ii){
		const auto &sp = spawns[ii];
		const uint32_t tick_prerate = particles::lifedata::time2tick(sp.rate);
		const uint32_t spawnnum = uint32_t((deltatick / float(tick_prerate)) * sp.count);
		spawn_particles(spawnnum, sp);
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
		if (t)
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
		auto q = sibling_component<particles::quad>(ID_color_interpolator, ii);
		const auto life = sibling_component<particles::life>(ID_color_interpolator, ii);

		const auto& ci = color_interpolators[ii];
		for (int iv = 0; iv < 4; ++iv) {
			uint8_t* rgba = (uint8_t*)(&(((*q)[iv]).color));
			for (int ii = 0; ii < 4; ++ii) {
				const auto& c = ci.rgba[ii];
				rgba[ii] = to_color_channel(c.get(to_color_channel(rgba[ii]), life->delta_process(dt)));
			}
		}
	}
}

void
particle_mgr::update_uv_motion(float dt){
	const auto &uvmotions = data<particles::uv_motion>();
	for (int ii=0; ii<(int)uvmotions.size(); ++ii){
		auto& q = *sibling_component<particles::quad>(ID_uv_motion, ii);
		const auto &uvm = uvmotions[ii];
		for (int ii=0; ii<4; ++ii){
			q[ii].uv = dt * uvm;
		}
	}
}

void
particle_mgr::update_quad_transform(float dt){
	auto& quads = data<particles::quad>();

	for (int iq = 0; iq < (int)quads.size(); ++iq) {
		quaddata* q = &quads[iq];

		const auto scale = sibling_component<particles::scale>(ID_quad, iq);
		const auto rotation = sibling_component<particles::rotation>(ID_quad, iq);
		const auto translation = sibling_component<particles::translation>(ID_quad, iq);
		if (scale == nullptr && rotation == nullptr && translation == nullptr)
			continue;

		glm::mat4 m = scale ? glm::scale(*scale) : glm::mat4(1.f);
		if (rotation)
			m = glm::mat4(*rotation) * m;
	
		if (translation)
			m = glm::translate(*translation) * m;

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
			i += mcomp_arrays[id]->remap(remap + i, n - i);
		}
	} while (n == cap);
}

void
particle_mgr::update(float dt){
	update_particle_spawn(dt);

	update_velocity(dt);
	update_translation(dt);
	update_uv_motion(dt);
	update_lifetime_color(dt);
	update_lifetime_scale(dt);

	update_quad_transform(dt);
	update_lifetime(dt);	// should be last update
	remap_particles();
	assert(0 == particlesystem_verify(mmgr));

	submit_render();
}
