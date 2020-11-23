#pragma once

#include "singleton.h"

#define PARTICLE_COMPONENT  10
extern "C"{
#include "psystem_manager.h"
}


enum component_id : uint32_t {
    ID_life = 0,
    ID_color,
    ID_uv,
    ID_velocity,
    ID_acceleration,
    ID_scale,
    ID_rotation,
    ID_translate,
    ID_TAG_transform,
    ID_render_quad,
    ID_count,
};

static_assert(PARTICLE_COMPONENT == ID_count, "define value 'PARTICLE_COMPONENT' need equal to 'ID_count'");

using comp_ids = std::vector<component_id>;

struct particles{
    struct lifetype {
        float time;
        float current;
        float delta;
    };

    template<typename T, component_id ID>
    class component_arrayT : public std::vector<T>{
    public:
        void add(comp_ids &ids, const T &v){
            assert(ids.end() == std::find(ids.begin(), ids.end(), ID));
            ids.push_back(ID);
            push_back(v);
        }
    };

    component_arrayT<lifetype,  ID_life>            life;
    component_arrayT<glm::vec3, ID_velocity>        velocity;
    component_arrayT<glm::vec3, ID_acceleration>    acceleration;
    component_arrayT<glm::vec3, ID_scale>           scale;
    component_arrayT<glm::quat, ID_rotation>        rotation;
    component_arrayT<glm::vec3, ID_translate>       translation;
    component_arrayT<uint32_t, ID_render_quad>      renderquad;
    particles(){
        life.reserve(UINT16_MAX);
        velocity.reserve(UINT16_MAX);
        acceleration.reserve(UINT16_MAX);
        scale.reserve(UINT16_MAX);
        rotation.reserve(UINT16_MAX);
        translation.reserve(UINT16_MAX);
    }
};

struct render_data{
    uint16_t viewid;
    uint16_t progid;
    render_data() : viewid(UINT16_MAX), progid(UINT16_MAX){}
    struct texture{
        uint16_t uniformid;
        uint16_t texid;
        texture() : uniformid(UINT16_MAX), texid(UINT16_MAX){}
    };
    std::vector<texture>   textures;
};

class particle_mgr : public singletonT<particle_mgr> {
    friend class singletonT<particle_mgr>;
private:
    particle_mgr();
    ~particle_mgr();
public:
    void update(float dt);

public:
    comp_ids&& start() { return std::move(comp_ids()); }
    bool end(comp_ids &&ids){ return 0 != particlesystem_add(mmgr, ids.size(), (int*)(&ids[0])); }
    
    void addlifetime(comp_ids& ids, const particles::lifetype &lt) { mparticles.life.add(ids, lt);}
    void addvelocity(comp_ids& ids,     const glm::vec3& v)    { mparticles.velocity.add(ids, v);}
    void addacceleration(comp_ids& ids, const glm::vec3& a)    { mparticles.acceleration.add(ids, a);}
    void addscale(comp_ids& ids,        const glm::vec3& s)    { mparticles.scale.add(ids, s);}
    void addrotation(comp_ids& ids,     const glm::quat& r)    { mparticles.rotation.add(ids, r);}
    void addtranslation(comp_ids& ids,  const glm::vec3& t)    { mparticles.translation.add(ids, t);}
    void addrenderquad(comp_ids& ids,   uint32_t idx)          { mparticles.renderquad.add(ids, idx);}

public:
    void set_render_info(uint16_t viewid, uint16_t progid){
        mrenderdata.progid = progid;
        mrenderdata.viewid = viewid;
    }

    void add_texture(uint16_t uniformid, uint16_t texid){
        mrenderdata.textures.push_back({uniformid, texid});
    }
private:
    void recap_particles();
    void submit_render();
private:
    particles mparticles;
    struct particle_manager *mmgr;

    render_data mrenderdata;
};