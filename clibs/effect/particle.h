#pragma once

#include "singleton.h"

struct particle {
    uint32_t    idx;
    float       lifetime;
    float       currenttime;

    glm::vec3   velocity;
    glm::vec3   acceleration;
    glm::mat4   transform;
    bool        isdead;
};

class particle_mgr : public singletonT<particle_mgr> {
    friend class singletonT<particle_mgr>;
private:
    particle_mgr();
public:
    uint16_t spawn_valid(uint16_t start);
    particle& get_particle(uint16_t idx) { assert(idx < mparticle_pool.size()); return mparticle_pool[idx];}

    void register_transform(const std::string &name, particle_transform *pt);
private:
    std::vector<particle>   mparticle_pool;
};

struct particles_set{
    uint16_t count;
    uint16_t indices[1];
};

// //TODO: this emitter only emit quad particle
// struct emitter {
//     std::vector<attribute*> attributes;
//     std::vector<particle>   particles;

//     void init(){
//         for (auto& p : particles){
//             for(auto att : attributes){
//                 att->init(p);
//             }
//         }
//     }

//     void update(){
//         for (auto& p : particles){
//             for (auto att : attributes){
//                 att->update(p);
//             }
//         }
//     }
// };
