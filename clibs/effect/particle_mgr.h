#pragma once
#include "singleton.h"
#include "particle.h"

class quad_cache;
class component_array;
struct particle_manager;
struct particle_remap;

struct render_data{
    uint16_t viewid             = UINT16_MAX;
    quad_buffer qb;
};

struct material {
    struct fx{
        uint32_t prog;
    };

    struct fx fx;

    struct state{
        uint64_t state;
        uint32_t rgba;
    };
    struct state state;

    struct uniform{
        uint32_t uniformid;
        glm::vec4 value;
    };
    struct texture{
        uint8_t stage;
        uint32_t uniformid;
        uint32_t texid;
    };
    struct properties {
        std::unordered_map<std::string, uniform>  uniforms;
        std::unordered_map<std::string, texture>    textures;
    };

    struct properties properties;
};

struct particle_stat{
    uint16_t count;
    uint16_t comp_count[ID_key_count];
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
    void particle_stat(struct particle_stat &stat) const;

private:
    void remove_particle(uint32_t pidx);
    void remap_particles() { mparticles.remap_particles(mmgr); }
public:
    render_data& get_rd() { return mrenderdata; }
    void register_material(uint8_t idx, material &&m){mmaterials[idx] = std::move(m);}
private:
    struct submit_batch{
        //TODO: use intstance render
        uint8_t materialidx;

    };
    using submit_batchs = std::vector<submit_batch>;
    using quad_list = std::list<uint16_t>;
    using quads_lists = std::vector<quad_list>;
    quads_lists sort_quads();
    void submit_buffer(const quad_list &l);
    void submit_render(uint8_t materialidx);
    void submit();
public:
    void update(float dt);
private:
    void update_lifetime(float dt);
    void update_velocity(float dt);
    void update_uv_motion(float dt);
    void update_translation(float dt);
    void update_lifetime_scale(float dt);
    void update_lifetime_rotation(float dt);
    void update_lifetime_color(float dt);

    template<typename T>
    T* sibling_component(component_id id, int ii);
    template<typename T>
    decltype(auto) data() { return mparticles.data<T>();}
private:
    particles mparticles;
    struct particle_manager *mmgr;

    render_data mrenderdata;
    std::unordered_map<uint8_t, material> mmaterials;
};