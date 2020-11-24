#include "pch.h"
#include "particle.h"
#include "transforms.h"
#include "quadcache.h"

#define PARTICLE_COMPONENT  ID_count
#include "psystem_manager.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

particle_mgr::particle_mgr()
    : mmgr(particlesystem_create()){
}

particle_mgr::~particle_mgr(){
    particlesystem_release(mmgr);
}

bool particle_mgr::end(comp_ids &&ids){
	const bool valid = 0 != particlesystem_add(mmgr, (int)ids.size(), (int*)(&ids[0]));
	if (valid){
		for (auto id : ids){
			switch (id){
			case ID_life: 
			break;
			case ID_color:{
				const int n = particlesystem_count(mmgr, ID_color);
				assert(n == mparticles.color.size());
				for (int iclr=0; iclr<n; ++iclr){
					const auto &qc = mparticles.color[iclr];
					const particle_index rq_idx = particlesystem_component(mmgr, ID_color, iclr, ID_render_quad);
					assert(rq_idx < mparticles.renderquad.size());
					if (rq_idx != PARTICLE_INVALID){
						assert(rq_idx < mparticles.renderquad.size());
						const uint32_t quadidx = mparticles.renderquad[rq_idx];
						for (uint32_t ii=0; ii<4; ++ii){
							const auto& c = qc[ii];
							const uint32_t ic = uint32_t(c.r * 255.f) << 0 |
												uint32_t(c.g * 255.f) << 8 |
												uint32_t(c.b * 255.f) << 16|
												uint32_t(c.a * 255.f) << 24;
							quad_cache::get().set_attrib(quadidx, ii, ic);
						}
					}

				}
			}
			break;
			case ID_uv:{
				const int n = particlesystem_count(mmgr, ID_uv);
				assert(n == mparticles.uv.size());
				for (int iuv=0; iuv<n; ++iuv){
					const auto &quv = mparticles.uv[iuv];
					const particle_index rq_idx = particlesystem_component(mmgr, ID_uv, iuv, ID_render_quad);
					if (rq_idx != PARTICLE_INVALID){
						assert(rq_idx < mparticles.renderquad.size());
						const uint32_t quadidx = mparticles.renderquad[rq_idx];
						for (uint32_t ii=0; ii<4; ++ii){
							quad_cache::get().set_attrib(quadidx, ii, quv[ii]);
						}
					}
				}
			}
			break;
			case ID_velocity:
			break;
			case ID_acceleration: 
			break;
			case ID_scale: 
			break;
			case ID_rotation: 
			break;
			case ID_translate: 
			break;
			case ID_TAG_transform: 
			break;
			case ID_render_quad: 
			break;
			default:
				assert(false && "invalid component id");
				break;
			}
		}
	} else {
		assert(false && "need recover data");
	}

	return valid;
}

static inline void
update_lifetime(float dt, particle_manager *mgr, particles &p){
    const int n = particlesystem_count(mgr, ID_life);
	assert(n == p.life.size());
    for(int ii=0; ii<n; ++ii){
		auto &l = p.life[ii];
        l.current = std::min(l.time, l.current + dt);

        if (l.current == l.time){
            particlesystem_remove(mgr, ID_life, (particle_index)ii);
        }
    }
}

static inline void
update_velocity(float dt, particle_manager *mgr, particles &p){
	const int n = particlesystem_count(mgr, ID_acceleration);
	assert(n == p.acceleration.size());
	for (int aidx=0; aidx<n; ++aidx){
		const auto &a = p.acceleration[aidx];
		auto vidx = particlesystem_component(mgr, ID_acceleration, (particle_index)aidx, ID_velocity);
		assert(vidx < p.velocity.size());
		auto &v = p.velocity[vidx];

		v += a * dt;
	}
}

static inline void
update_translation(float dt, particle_manager *mgr, particles &p){
	const int n = particlesystem_count(mgr, ID_velocity);
	assert(n == p.velocity.size());
	for (int vidx=0; vidx<n; ++vidx){
		const auto &v = p.velocity[vidx];
		auto tidx = particlesystem_component(mgr, ID_velocity, (particle_index)vidx, ID_translate);
		assert(tidx < p.translation.size());
		auto &t = p.translation[vidx];

		t += v * dt;
	}
}

static inline void
update_quad_transform(float dt, particle_manager *mgr, particles &p){
	const int n = particlesystem_count(mgr, ID_render_quad);

	for (particle_index pidx=0; pidx<n; ++pidx){
		const uint32_t quadidx = p.renderquad[pidx];
		quad_cache::get().init_transform(quadidx);
	
		const particle_index sidx = particlesystem_component(mgr, ID_render_quad, pidx, ID_scale);
		if (sidx != PARTICLE_INVALID){
			quad_cache::get().scale(quadidx, p.scale[sidx]);
		}
		const particle_index rotidx = particlesystem_component(mgr, ID_render_quad, pidx, ID_rotation);
		if (rotidx != PARTICLE_INVALID){
			quad_cache::get().rotate(quadidx, p.rotation[rotidx]);
		}
		const particle_index tidx = particlesystem_component(mgr, ID_render_quad, pidx, ID_translate);
		if (tidx != PARTICLE_INVALID){
			quad_cache::get().translate(quadidx, p.translation[tidx]);
		}
	}
}

void
particle_mgr::submit_render(){
#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)
	BGFX(set_state(uint64_t(RENDER_STATE), 0));

	const uint32_t offset = (uint32_t)mparticles.renderquad[0];
	quad_cache::get().submit(offset, (uint32_t)mparticles.renderquad.size());
	quad_cache::get().update();
	for (size_t ii=0; ii<mrenderdata.textures.size(); ++ii){
		const auto &t = mrenderdata.textures[ii];
		BGFX(set_texture)((uint8_t)ii, {t.uniformid}, {t.texid}, UINT16_MAX);
	}
	
	BGFX(submit)(mrenderdata.viewid, {mrenderdata.progid}, 0, BGFX_DISCARD_ALL);
}

template<typename T, component_id ID>
void particles::component_arrayT<T, ID>::remap(const particle_remap &m){
	if (m.to_id != PARTICLE_INVALID) {
		(*this)[m.to_id] = (*this)[m.from_id];
	} else {
		this->resize(m.from_id);
	}
}

void
particle_mgr::recap_particles(){
    struct particle_remap remap[128];
	struct particle_arrange_context ctx;
	int cap = sizeof(remap)/sizeof(remap[0]);
	int n;
	do {
		n = particlesystem_arrange(mmgr, cap, remap, &ctx);
		for (int i=0;i<n;i++) {
			const auto &rm = remap[i];
			switch(remap[i].component_id) {
			case ID_life:
				mparticles.life.remap(rm);
				break;
			case ID_velocity:
				mparticles.velocity.remap(rm);
				break;
			case ID_acceleration:
				mparticles.acceleration.remap(rm);
				break;
			case ID_color:
				mparticles.color.remap(rm);
				break;
			case ID_uv:
				mparticles.uv.remap(rm);
				break;
			case ID_scale:
				mparticles.scale.remap(rm);
				break;
			case ID_rotation:
				mparticles.rotation.remap(rm);
				break;
			case ID_translate:
				mparticles.translation.remap(rm);
				break;
			//ignore
			case ID_TAG_transform:
				break;
			case ID_render_quad:
				mparticles.renderquad.remap(rm);
				break;
			default:
				assert(false && "unsupport component");
				break;
			}
		}
	} while (n == cap);
}

void
particle_mgr::update(float dt){
	update_velocity(dt, mmgr, mparticles);
	update_translation(dt, mmgr, mparticles);
	update_lifetime(dt, mmgr, mparticles);
	update_quad_transform(dt, mmgr, mparticles);
	recap_particles();

	//TODO: we can fully control render in lua level, only need vertex buffer in quad_cache
	submit_render();
}
