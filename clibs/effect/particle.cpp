#include "pch.h"
#include "particle.h"

particle_mgr::particle_mgr(uint16_t maxnum)
    : mparticle_pool(maxnum){}

uint16_t particle_mgr::spawn_valid(uint16_t offset){
    //TODO: need another method to quickly find which particle is dead
    for (uint16_t ii=offset; ii<mparticle_pool.size(); ++ii){
        const auto &p = mparticle_pool[ii];
        if (p.isdead){
            return ii;
        }
    }
    return UINT16_MAX;
}
