#pragma once
#include "singleton.h"
#include "particle.h"

class quad_cache;
class component_array;
struct particle_manager;
struct particle_remap;

struct render_data{
    uint16_t viewid             = UINT16_MAX;
    uint16_t progid             = UINT16_MAX;
    quad_buffer qb;
    struct texture{
        uint16_t stage;
        uint16_t uniformid;
        uint16_t texid;
        texture(uint16_t uid = UINT16_MAX, uint16_t tid=UINT16_MAX) : uniformid(uid), texid(tid){}
    };
    std::vector<texture>   textures;
};

//TODO: need remove this singletonT, push it in lua_State
class particle_mgr : public singletonT<particle_mgr> {
    friend class singletonT<particle_mgr>;
private:
    particle_mgr();
    ~particle_mgr();
public:
    bool add(const comp_ids &ids);
    template<typename T>
    component_id add_component(const T &v) { return mparticles.add_component(v);}

    template<typename T>
    T& component_value(int idx = -1) {return mparticles.component_value<T>(idx);}
private:
    void remove_particle(uint32_t pidx);
    void remap_particles() { mparticles.remap_particles(mmgr); }
public:
    render_data& get_rd() { return mrenderdata; }
private:
    void submit_render();
    uint32_t submit_buffer();
public:
    void update(float dt);
private:
    void update_lifetime(float dt);
    void update_velocity(float dt);
    void update_translation(float dt);
    void update_lifetime_scale(float dt);
    void update_lifetime_rotation(float dt);
    void update_lifetime_color(float dt);
    void update_lifetime_subuv_index(float dt);
    void update_uv_motion(float dt);
    void update_quad_transform(float dt);

    template<typename T>
    T* sibling_component(component_id id, int ii);
    template<typename T>
    decltype(auto) data() { return mparticles.data<T>();}
private:
    particles mparticles;
    struct particle_manager *mmgr;

    render_data mrenderdata;
};