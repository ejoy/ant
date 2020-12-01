#include "pch.h"
#include "particle.h"
#include "transforms.h"
#include "quadcache.h"

#include "random.h"

#define PARTICLE_COMPONENT		ID_count
#define PARTICLE_KEY_COMPONENT	ID_key_count
#include "psystem_manager.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

particle_mgr::particle_mgr()
    : mmgr(particlesystem_create()){
}

particle_mgr::~particle_mgr(){
    particlesystem_release(mmgr);
}

class component_array {
public:
	virtual ~component_array()              = default;
	virtual void remap(int from, int to)    = 0;
	virtual void shrink(int n)              = 0;
	virtual void pop_back()                 = 0;
};

template<typename T>
class component_arrayT : public component_array {
public:
	component_id add(T &&v){
		mdata.push_back(std::move(v));
		return T::ID;
	}
	std::vector<T> mdata;
};

template<typename T>
class component_objects : public component_arrayT<T> {
	using base = component_arrayT<T>;
public:

	virtual ~component_objects() = default;

	virtual void remap(int from, int to) override {
		this->mdata[from] = std::move(this->mdata[to]);
	}

	virtual void shrink(int n) override{
		this->mdata.resize(n);
	}

	virtual void pop_back() override{
		this->mdata.pop_back();
	}
};

template<typename T>
class component_pointers : public component_arrayT<T*>{
public:
	virtual ~component_pointers(){
		for (auto &p : this->mdata){
			delete p;
		}
	}
	virtual void remap(int from, int to) override {
		delete this->mdata[to];
		this->mdata[to] = this->mdata[from];
		this->mdata[from] = nullptr;
	}

	virtual void shrink(int n) override{
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
	return static_cast<component_arrayT<T>*>(mcomp_arrays[T::ID])->mdata;
}

template<typename VALUE_TYPE, int NUM, typename INTERP_TYPE>
static VALUE_TYPE
interp_vec(const INTERP_TYPE &iv, randomobj &ro){
	VALUE_TYPE v;
	for (uint32_t ii=0; ii<NUM; ++ii){
		const auto &vs = iv.scale[ii];
		v[ii] = vs.scale * particles::lifedata::MAX_PROCESS;
		if (is_linear_interp(vs.type)){
			const float random = ro();
			v[ii] *= random;
		}
	}

	return v;
}

static uint32_t
interp_color(const particles::v4_interp_value &iv, randomobj &ro){
	uint8_t c[4] = {0};
	for (uint32_t ii=0; ii<4;++ii){
		const auto &s = iv.scale[ii];
		const float v = s.scale * particles::lifedata::MAX_PROCESS;
		c[ii] = uint8_t(v);
		if (is_linear_interp(s.type)){
			c[ii] = uint8_t(v * ro());
		}
	}
	
	return uint32_t(c[0]<<0|c[1]<<8|c[2]<<16|c[3]<<24);
}

void
particle_mgr::spawn_particles(float dt, uint32_t spawnidx, const particles::spawndata &sd){
	const float num_pre_second = float(sd.count) / sd.rate;

	const uint32_t spawnnum = uint32_t(dt * num_pre_second + 0.5f);

	if (spawnnum > 0){
		struct spawn_id{
			component_id id;
			particle_index idx;
		};
		const component_id init_ids[] = {
			// spawn init
			ID_init_life_interpolator,
			ID_init_velocity_interpolator,
			ID_init_acceleration_interpolator,
			ID_init_render_interpolator,
			
			// lifetime
			ID_lifetime_spawn_interpolator,
			ID_init_velocity_interpolator,
			ID_init_acceleration_interpolator,
			ID_init_render_interpolator,
		};

		std::vector<spawn_id>	particle_indices;

		//TODO: should be gloabl value
		std::unordered_map<component_id, std::function<component_id (uint32_t idx, randomobj &ro)>>	create_component_ops = {
			std::make_pair(ID_init_life_interpolator, [this](uint32_t idx, randomobj &ro){
				const auto &init_life_interpolator = data<particles::init_life_interpolator>();
				const auto& interp_life = init_life_interpolator[idx].comp;

				float life = interp_life.scale * particles::lifedata::MAX_PROCESS;
				if (is_linear_interp(interp_life.type))
					life *= ro();
				return component(particles::life{particles::lifedata(life)});
			}),

			std::make_pair(ID_init_velocity_interpolator, [this](uint32_t idx, randomobj &ro){
				const auto &init_vel_interp = data<particles::init_velocity_interpolator>();
				return component(particles::velocity{interp_vec<glm::vec3, 3>(init_vel_interp[idx].comp, ro)});
			}),

			std::make_pair(ID_init_acceleration_interpolator, [this](uint32_t idx, randomobj &ro){
				const auto &init_acc_interp = data<particles::init_acceleration_interpolator>();
				return component(particles::velocity{interp_vec<glm::vec3, 3>(init_acc_interp[idx].comp, ro)});
			}),

			std::make_pair(ID_init_render_interpolator, [this](uint32_t idx, randomobj &ro){
				const auto &init_render_interp = data<particles::init_rendertype_interpolator>();
				const auto &render_interp = init_render_interp[idx].comp;
				particles::renderdata rd;
				rd.s = interp_vec<glm::vec3, 3>(render_interp.s, ro);
				rd.t = interp_vec<glm::vec3, 3>(render_interp.t, ro);

				rd.color = interp_color(render_interp.color, ro);
				
				for(uint32_t ii=0; ii<4; ++ii){
					rd.uv[ii] = interp_vec<glm::vec2, 2>(render_interp.uv[ii], ro);
				}

				return component(particles::rendertype{rd});
			}),
		};

		for (auto initid : init_ids){
			const particle_index idx = particlesystem_component(mmgr, ID_spawn, spawnidx, initid);
			if (PARTICLE_INVALID != idx)
				particle_indices.push_back(spawn_id{initid, idx});
		}

		randomobj ro;
		for (uint32_t ii=0; ii<spawnnum; ++ii){
			comp_ids ids;
			for (auto p : particle_indices){
				auto it = create_component_ops.find(p.id);
				if (it != create_component_ops.end()){
					ids.push_back(it->second(p.idx, ro));
				}
			}
		
			add(ids);
		}
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
particle_mgr::update_lifetime(float dt){
	auto &lifes = data<particles::life>();
	for (size_t ii=0; ii<lifes.size(); ++ii){
		auto &c = lifes[ii].comp;
		c.current += dt;
		if (c.update_process()){
			particlesystem_remove(mmgr, ID_life, (particle_index)ii);
		}
    }
}

void
particle_mgr::update_particle_spawn(float dt){
	const int n = particlesystem_count(mmgr, ID_TAG_emitter);
	for (int ii=0; ii<n; ++ii){
		const auto &sp = data<particles::spawn>()[ii].comp;
		const auto idx = particlesystem_component(mmgr, ID_TAG_emitter, ii, ID_spawn);
		spawn_particles(dt, idx, sp);
	}
}

void
particle_mgr::update_velocity(float dt){
	const auto &acc = data<particles::acceleration>();
	auto &vel = data<particles::velocity>();
	for (size_t aidx=0; aidx<acc.size(); ++aidx){
		const auto &a = acc[aidx].comp;
		auto vidx = particlesystem_component(mmgr, ID_acceleration, (particle_index)aidx, ID_velocity);
		assert(vidx < vel.size());
		auto &v = vel[vidx].comp;
		v += a * dt;
	}
}

void
particle_mgr::update_translation(float dt){
	const auto &vel = data<particles::velocity>();
	auto &render = data<particles::rendertype>();

	for (size_t vidx=0; vidx<vel.size(); ++vidx){
		const auto &v = vel[vidx].comp;
		auto tidx = particlesystem_component(mmgr, ID_velocity, (particle_index)vidx, ID_render);
		if (tidx != PARTICLE_INVALID){
			auto &r = render[vidx].comp;
			r.t += v * dt;
		}
	}
}

void
particle_mgr::update_quad_transform(float dt){
	for (const auto& r : data<particles::rendertype>()){
		const auto& c = r.comp;
		const uint32_t quadidx = c.quadidx;
		glm::mat4 m = glm::scale(c.s);
		m = glm::mat4(c.r) * m;
		m = glm::translate(c.t) * m;

		quad_cache::get().transform(quadidx, m);
		for (uint32_t ii=0; ii<4; ++ii){
			quad_cache::get().set_attrib(quadidx, ii, c.color);
			quad_cache::get().set_attrib(quadidx, ii, c.uv[ii]);
		}
	}
}

void
particle_mgr::submit_render(){
	//TODO: quad_cache::submit() should call from lua update not here
	quad_cache::get().submit(0, (uint32_t)data<particles::rendertype>().size()); 
	quad_cache::get().update();
	BGFX(set_state(uint64_t(BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA), 0));

	for (size_t ii=0; ii<mrenderdata.textures.size(); ++ii){
		const auto &t = mrenderdata.textures[ii];
		BGFX(set_texture)((uint8_t)ii, {t.uniformid}, {t.texid}, UINT16_MAX);
	}
	
	BGFX(submit)(mrenderdata.viewid, {mrenderdata.progid}, 0, BGFX_DISCARD_ALL);
}

void
particle_mgr::recap_particles(){
    struct particle_remap remap[128];
	struct particle_arrange_context ctx;
	int cap = sizeof(remap)/sizeof(remap[0]);
	int n;
	do {
		n = particlesystem_arrange(mmgr, cap, remap, &ctx);
		for (int ii=0; ii<n; ++ii){
			if (remap[ii].to_id != PARTICLE_INVALID){
				mcomp_arrays[remap[ii].component_id]->remap(remap[ii].from_id, remap[ii].to_id);
			} else {
				mcomp_arrays[remap[ii].component_id]->shrink(remap[ii].from_id);
			}
		}
	} while (n == cap);
}

void
particle_mgr::update(float dt){
	update_velocity(dt);
	update_translation(dt);
	update_lifetime(dt);
	update_quad_transform(dt);
	recap_particles();

	//TODO: we can fully control render in lua level, only need vertex buffer in quad_cache
	submit_render();
}
