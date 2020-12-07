#pragma once

#include "singleton.h"
#include "quadcache.h"
enum component_id : uint32_t {
    ID_life = 0,
    ID_spawn,
    ID_velocity,
    ID_acceleration,
    ID_transform,
    ID_quad,
    ID_uv_motion,
    ID_material,

    ID_init_interpolator_start,
    ID_init_life_interpolator = ID_init_interpolator_start,
    ID_init_spawn_interpolator,
    ID_init_velocity_interpolator,
    ID_init_acceleration_interpolator,
    ID_init_transform_interpolator,
    ID_init_uv_motion_interpolator,
    ID_init_quad_interpolator,
    ID_init_interpolator_end = ID_init_quad_interpolator,

    ID_lifetime_interpolator_start,
    ID_lifetime_life_interpolator = ID_lifetime_interpolator_start,
    ID_lifetime_spawn_interpolator,
    ID_lifetime_velocity_interpolator,
    ID_lifetime_acceleration_interpolator,
    ID_lifetime_transform_interpolator,
    ID_lifetime_uv_motion_interpolator,
    ID_lifetime_quad_interpolator,
    ID_lifetime_interpolator_end = ID_lifetime_quad_interpolator,

    ID_key_count,

    ID_TAG_emitter,
    ID_TAG_uv_motion,
    ID_TAG_uv,
    ID_TAG_color,
    ID_TAG_scale,
    ID_TAG_rotation,
    ID_TAG_translate,
    ID_TAG_render_quad,
    ID_TAG_material,
    ID_count,
};

using comp_ids = std::vector<component_id>;


template<class T>
inline constexpr T pow(const T base, const uint32_t exponent){
    uint32_t v = 1;
    for(uint32_t ii=1; ii<exponent; ++ii){
        v *= base;
    }
    return v;
}

template<typename T, component_id COMP_ID>
struct componentT : public T {
    static constexpr component_id ID() { return COMP_ID; }
};

struct particle_remap;
struct particles{
    struct lifedata {
        using interp_type = float;
        static inline const float   FREQUENCY           = 1/60.f;
        static const uint32_t       MAX_PROCESS_BITS    = 10;
        static const uint32_t       MAX_TICK_BITS       = 22;
        static const uint32_t       MAX_PROCESS         = pow(2, MAX_PROCESS_BITS);

        static inline uint32_t time2tick(float t_in_second){
            return uint32_t(t_in_second / FREQUENCY + 0.5 / FREQUENCY);
        }

        inline bool isdead() const{ return process >= tick; }
        inline bool update_process() {
            process = uint32_t((time2tick(current) / float(tick)) * MAX_PROCESS);
            return isdead();
        }

        inline float normalize_process() const {
            return (process / float(particles::lifedata::MAX_PROCESS));
        }

        lifedata(uint32_t t) : tick(t), process(0), current(0.f){}
        lifedata(float t) : tick(time2tick(t)), process(0), current(0.f){}
        lifedata() : tick(0), process(0), current(0.f){}
        void set(float t) {tick = time2tick(t); process = 0; current = 0.f;}
        uint32_t tick   : MAX_TICK_BITS;
        uint32_t process: MAX_PROCESS_BITS;
        float    current;
    };

    struct spawndata {
        uint32_t    count;
        float       rate;
    };

    struct transformdata {
        glm::vec3 s;
        glm::quat r;
        glm::vec3 t;
    };

    struct materialdata {
        uint8_t idx;
    };

    struct uv_motion_data{
        float u_speed, v_speed;
        float scale;
    };

    template<typename INTERP_VALUE>
    struct interp_valueT{
        using interp_type = INTERP_VALUE;
        interp_valueT():scale(0), type(UINT8_MAX){}
        INTERP_VALUE scale;
        uint8_t type;   //0 for const, 1 for linear, [2, 254] for curve index
    };

    using float_interp_value    = interp_valueT<float>;
    using f2_interp_value       = interp_valueT<glm::vec2>;
    using f3_interp_value       = interp_valueT<glm::vec3>;
    using f4_interp_value       = interp_valueT<glm::vec4>;
    using quad_interp_value     = interp_valueT<glm::quat>;

    struct color_interp_value{
        float_interp_value rgba[4];
    };

    struct transform_interp{
        f3_interp_value s;
        float_interp_value r;
        f3_interp_value t;
    };

    struct quad_interp{
        //f2_interp_value uv[4];
        color_interp_value color;
    };

    struct uv_motion_interp_value{
        
    };

    using life          = componentT<lifedata,       ID_life>;
    using spawn         = componentT<spawndata,      ID_spawn>;
    using velocity      = componentT<glm::vec3,      ID_velocity>;
    using acceleration  = componentT<glm::vec3,      ID_acceleration>;
    using transform    = componentT<transformdata,   ID_transform>;
    using uv_motion     = componentT<uv_motion_data, ID_uv_motion>;
    using quad          = componentT<quaddata,       ID_quad>;
    using material      = componentT<materialdata,   ID_material>;

    using init_life_interpolator        = componentT<float_interp_value,ID_init_life_interpolator>;
    using init_spawn_interpolator       = componentT<float_interp_value,ID_init_spawn_interpolator>;
    using init_velocity_interpolator    = componentT<f3_interp_value,   ID_init_velocity_interpolator>;
    using init_acceleration_interpolator= componentT<f3_interp_value,   ID_init_acceleration_interpolator>;
    using init_transform_interpolator   = componentT<transform_interp,  ID_init_transform_interpolator>;
    using init_quad_interpolator        = componentT<quad_interp,       ID_init_quad_interpolator>;
    using init_uv_motion_interpolator   = componentT<uv_motion_interp_value, ID_init_uv_motion_interpolator>;

    using lifetime_life_interpolator         = componentT<float_interp_value,ID_lifetime_life_interpolator>;
    using lifetime_spawn_interpolator        = componentT<float_interp_value,ID_lifetime_spawn_interpolator>;
    using lifetime_velocity_interpolator     = componentT<f3_interp_value,   ID_lifetime_velocity_interpolator>;
    using lifetime_acceleration_interpolator = componentT<f3_interp_value,   ID_lifetime_acceleration_interpolator>;
    using lifetime_transform_interpolator    = componentT<transform_interp, ID_lifetime_transform_interpolator>;
    using lifetime_quad_interpolator         = componentT<quad_interp,       ID_lifetime_quad_interpolator>;
    using lifetime_uv_motion_interpolator    = componentT<uv_motion_interp_value, ID_lifetime_uv_motion_interpolator>;
};

struct render_data{
    uint16_t viewid             = UINT16_MAX;
    uint16_t progid             = UINT16_MAX;
    bgfx_vertex_layout_t *layout= nullptr;
    uint16_t ibhandle           = UINT16_MAX;
    struct texture{
        uint16_t stage;
        uint16_t uniformid;
        uint16_t texid;
        texture(uint16_t uid = UINT16_MAX, uint16_t tid=UINT16_MAX) : uniformid(uid), texid(tid){}
    };
    std::vector<texture>   textures;
};

class quad_cache;
class component_array;
struct particle_manager;

class particle_mgr : public singletonT<particle_mgr> {
    friend class singletonT<particle_mgr>;
private:
    particle_mgr();
    ~particle_mgr();
public:
    void update(float dt);

public:
    //TODO: need check ID_TAG_* has corresponding component in comp_ids
    bool add(const comp_ids &ids);
    void pop_back(const comp_ids &ids);
    template<typename T>
    component_id add_component(const T &v){ data<T>().push_back(v); return T::ID(); }

    template<typename T>
    T& component_value(int idx = -1) {
        return (idx < 0) ?
             data<T>().back() : 
             data<T>()[idx];
    }
public:
    render_data& get_rd() { return mrenderdata; }
private:
    template<typename T>
    std::vector<T>& data();
    
    template<typename T>
    void create_array();

    void spawn_particles(uint32_t spawnnum, uint32_t spawnidx, const particles::spawndata &sd);
    void remove_particle(uint32_t pidx);
    void remap_particles();

private:
    void submit_render();
    void submit_buffer();
private:
    void update_lifetime(float dt);
    void update_particle_spawn(float dt);
    void update_velocity(float dt);
    void update_translation(float dt);
    void update_lifetime_scale(float dt);
    void update_lifetime_rotation(float dt);
    void update_lifetime_color(float dt);
    void update_uv_motion(float dt);
    void update_quad_transform(float dt);

private:
    particles mparticles;
    struct particle_manager *mmgr;

    render_data mrenderdata;
    component_array *mcomp_arrays[ID_key_count];
};