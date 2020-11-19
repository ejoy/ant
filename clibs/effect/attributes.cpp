#include "pch.h"

#include "particle.h"
#include "quadcache.h"

#include "attributes.h"
#include "random.h"

// bool scale_attribute::init(const particles_set &ps){
//     for (uint16_t ii=0; ii<ps.count; ++ii){
//         auto &p = particle_mgr::get().get_particle(ps.indices[ii]);
        
//     }

//     return true;
// }

bool scale_attribute::update(const particles_set &ps, float deltatime){
    for (uint16_t ii=0; ii<ps.count; ++ii){
        auto &p = particle_mgr::get().get_particle(ps.indices[ii]);

        if (!p.isdead){
            p.currenttime = std::min(p.currenttime + deltatime, p.lifetime);

            float t = p.currenttime / p.lifetime;
            auto s = minterpolate->interpolate(t);
            //p.transform = glm::scale(s) * p.transform;
            quad_cache::get().scale(p.idx, s);

            p.isdead = glm::abs(p.currenttime - p.lifetime) <= 10e-6;
        }
    }

    return true;
}