#pragma once

#include "singleton.h"

enum component_id : uint32_t {
    ID_life = 0,
    ID_spawn,
    ID_velocity,
    ID_acceleration,
    ID_render,
    ID_uv_motion,

    ID_init_life_interpolator,
    ID_init_spawn_interpolator,
    ID_init_velocity_interpolator,
    ID_init_acceleration_interpolator,
    ID_init_render_interpolator,
    ID_init_uv_motion_interpolator,

    ID_lifetime_life_interpolator,
    ID_lifetime_spawn_interpolator,
    ID_lifetime_velocity_interpolator,
    ID_lifetime_acceleration_interpolator,
    ID_lifetime_render_interpolator,
    ID_lifetime_uv_motion_interpolator,

    ID_key_count,

    ID_TAG_emitter,
    ID_TAG_uv_motion,
    ID_TAG_uv,
    ID_TAG_scale,
    ID_TAG_rotation,
    ID_TAG_translate,
    ID_TAG_render_quad,
    ID_TAG_material,
    ID_TAG_color,
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
struct componentT {
    T comp;
    enum {ID=COMP_ID};
};

struct particle_remap;
struct particles{
    struct lifedata {
        static inline const float   FREQUENCY           = 1/60.f;
        static const uint32_t       MAX_PROCESS_BITS    = 10;
        static const uint32_t       MAX_TICK_BITS       = 22;
        static const uint32_t       MAX_PROCESS         = pow(2, MAX_PROCESS_BITS);

        static inline uint32_t time2tick(float t_in_second){
            return uint32_t(t_in_second / FREQUENCY + 0.5 / FREQUENCY);
        }

        inline bool isdead() const{ return process < tick; }
        inline bool update_process() {
            process = time2tick(current);
            return isdead();
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

    struct renderdata {
        glm::vec3 s;
        glm::quat r;
        glm::vec3 t;
        glm::vec2 uv[4];
        uint32_t color;
        uint32_t quadidx;
        uint8_t material;
    };

    struct uv_motion_data{
        float u_speed, v_speed;
        float scale;
    };

    struct float_interp_value{
        float   scale;
        int     type;   //0 for const, 1 for linear, [2, 255] for curve index
    };

    struct v3_interp_value{
        float_interp_value scale[3];
    };

    struct v2_interp_value {
        float_interp_value scale[2];
    };

    struct v4_interp_value{
        float_interp_value scale[4];
    };

    struct quad_interp_value{
        glm::quat scale;
        int type;
    };

    struct rendertype_interp{
        v3_interp_value s;
        quad_interp_value r;
        v3_interp_value t;

        v2_interp_value uv[4];
        v4_interp_value color;
    };

    using life          = componentT<lifedata, ID_life>;
    using spawn         = componentT<spawndata, ID_spawn>;
    using velocity      = componentT<glm::vec3, ID_velocity>;
    using acceleration  = componentT<glm::vec3, ID_acceleration>;
    using rendertype    = componentT<renderdata, ID_render>;
    using uv_moitoin    = componentT<uv_motion_data, ID_render>;

    using init_life_interpolator        = componentT<float_interp_value,ID_init_life_interpolator>;
    using init_spawn_interpolator       = componentT<float_interp_value,ID_init_spawn_interpolator>;
    using init_velocity_interpolator    = componentT<v3_interp_value,   ID_init_velocity_interpolator>;
    using init_acceleration_interpolator= componentT<v3_interp_value,   ID_init_acceleration_interpolator>;
    using init_rendertype_interpolator  = componentT<rendertype_interp, ID_init_render_interpolator>;

    using lifetime_life_interpolator         = componentT<float_interp_value,ID_lifetime_life_interpolator>;
    using lifetime_spawn_interpolator        = componentT<float_interp_value,ID_lifetime_spawn_interpolator>;
    using lifetime_velocity_interpolator     = componentT<v3_interp_value,   ID_lifetime_velocity_interpolator>;
    using lifetime_acceleration_interpolator = componentT<v3_interp_value,   ID_lifetime_acceleration_interpolator>;
    using lifetime_rendertype_interpolator   = componentT<rendertype_interp, ID_lifetime_render_interpolator>;
};

struct render_data{
    uint16_t viewid;
    uint16_t progid;
    render_data() : viewid(UINT16_MAX), progid(UINT16_MAX){}
    struct texture{
        uint16_t stage;
        uint16_t uniformid;
        uint16_t texid;
        texture(uint16_t uid = UINT16_MAX, uint16_t tid=UINT16_MAX) : uniformid(uid), texid(tid){}
    };
    std::vector<texture>   textures;
};

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
    bool add(const comp_ids &ids);
    void pop_back(const comp_ids &ids);
    template<typename T>
    component_id component(T &&v){ data<T>().push_back(v); return (component_id)T::ID; }
public:
    render_data& get_rd() { return mrenderdata; }
private:
    void recap_particles();
    void submit_render();

    template<typename T>
    std::vector<T>& data();

    void spawn_particles(float dt, uint32_t spawnidx, const particles::spawndata &sd);

public:
    void update_lifetime(float dt);
    void update_particle_spawn(float dt);
    void update_velocity(float dt);
    void update_translation(float dt);
    void update_quad_transform(float dt);
private:
    particles mparticles;
    struct particle_manager *mmgr;

    render_data mrenderdata;

    component_array *mcomp_arrays[ID_key_count];
};