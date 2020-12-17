#include "pch.h"
#include "particle.h"
#include "quadcache.h"

#include "random.h"
#include "particle.inl"

#include "lua2struct.h"

particles::particles(){
	create_array<particles::life>();
	create_array<particles::velocity>();
	create_array<particles::acceleration>();
	create_array<particles::scale>();
	create_array<particles::rotation>();
	create_array<particles::translation>();
	create_array<particles::uv>();
	create_array<particles::uv_motion>();
	create_array<particles::subuv>();
	create_array<particles::subuv_motion>();
	create_array<particles::color>();
	create_array<particles::material>();
	
	create_array<particles::velocity_interpolator>();
	create_array<particles::acceleration_interpolator>();
	create_array<particles::scale_interpolator>();
	create_array<particles::translation_interpolator>();
	create_array<particles::color_interpolator>();
}

template<typename T>
void particles::create_array(){
	using TT = typename std::remove_pointer<T>::type;
	mcomp_arrays[TT::ID()] = new component_arrayT<T>();
}


particles::~particles(){
	for (auto& ca : mcomp_arrays){
		delete ca;
		ca = nullptr;
	}
}

void
particles::pop_back(const comp_ids &ids){
	for(auto id : ids){
		mcomp_arrays[id]->pop_back();
	}
}

void
particles::remap_particles(struct particle_manager *pm){
    struct particle_remap remap[128];
	struct particle_arrange_context ctx;
	int cap = sizeof(remap)/sizeof(remap[0]);
	int n;
	do {
		n = particlesystem_arrange(pm, cap, remap, &ctx);
		int i = 0;
		while (i < n) {
			int id = remap[i].component_id;
			i += mcomp_arrays[id]->remap(remap + i, n - i);
		}
	} while (n == cap);
}