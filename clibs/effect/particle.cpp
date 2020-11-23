#include "pch.h"
#include "particle.h"
#include "transforms.h"
#include "quadcache.h"

extern bgfx_interface_vtbl_t* ibgfx();
#define BGFX(_API) ibgfx()->_API

particle_mgr::particle_mgr()
    : mmgr(particlesystem_create()){
}

particle_mgr::~particle_mgr(){
    particlesystem_release(mmgr);
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
	assert(n == p.acceleration.size());
	for (int vidx=0; vidx<n; ++vidx){
		const auto &v = p.velocity[vidx];
		auto tidx = particlesystem_component(mgr, ID_acceleration, (particle_index)vidx, ID_translate);
		assert(tidx < p.translation.size());
		auto &t = p.translation[vidx];

		t += v * dt;
	}
}

static inline void
update_quad_transform(particle_index pidx, uint32_t quadidx, particle_manager *mgr, particles &p){
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

void
particle_mgr::submit_render(){
	const int n = particlesystem_count(mmgr, ID_render_quad);

	for (particle_index pidx=0; pidx<n; ++pidx){
		const uint32_t quadidx = mparticles.renderquad[pidx];
		update_quad_transform(pidx, quadidx, mmgr, mparticles);
	}

#define RENDER_STATE (BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_BLEND_ALPHA|BGFX_STATE_MSAA)
	BGFX(set_state(uint64_t(RENDER_STATE), 0));

	const uint32_t offset = (uint32_t)mparticles.renderquad[0];
	quad_cache::get().submit(offset, n);
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
		for (int i=0;i<n;i++) {
			switch(remap[i].component_id) {
			case ID_life:
				if (remap[i].to_id != PARTICLE_INVALID) {
					mparticles.life[remap[i].to_id] = mparticles.life[remap[i].from_id];
				} else {
					mparticles.life.resize(remap[i].from_id);
				}
				break;
			case ID_velocity:
				if (remap[i].to_id != PARTICLE_INVALID) {
					mparticles.velocity[remap[i].to_id] = mparticles.velocity[remap[i].from_id];
				} else {
					mparticles.velocity.resize(remap[i].from_id);
				}
				break;
			case ID_acceleration:
				if (remap[i].to_id != PARTICLE_INVALID) {
					mparticles.acceleration[remap[i].to_id] = mparticles.acceleration[remap[i].from_id];
				} else {
					mparticles.acceleration.resize(remap[i].from_id);
				}
				break;
			}
		}
	} while (n == cap);
}

void
particle_mgr::update(float dt){
    update_lifetime(dt, mmgr, mparticles);

	recap_particles();
}
