#pragma once

#include "singleton.h"
#include "quadcache.h"
enum component_id : uint32_t {
    ID_life = 0,
    ID_spawn,
    ID_velocity,
    ID_acceleration,
    ID_scale,
    ID_rotation,
    ID_translation,
    ID_uv_motion,
    ID_quad,
    ID_material,

    ID_key_count,

    ID_interpolator_start,
    ID_velocity_interpolator = ID_interpolator_start,
    ID_acceleration_interpolator,
    ID_scale_interpolator,
    ID_rotation_interpolator,
    ID_translation_interpolator,
    ID_uv_motion_interpolator,
    ID_color_interpolator,
    ID_interpolator_end = ID_color_interpolator,

    ID_component_count,

    ID_TAG_emitter,
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
    using T::T;
    componentT(const T&t) : T(t){}
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

        inline uint32_t which_process(float t_in_second) const {
            return uint32_t((time2tick(t_in_second) / float(tick)) * MAX_PROCESS);
        }

        inline uint32_t delta_process(float dt) const {
            return which_process(current+dt) - process;
        }

        inline bool isdead() const{ return process >= tick; }
        inline bool update_process() {
            process = which_process(current);
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

    struct materialdata {
        uint8_t idx;
    };

    struct spawndata {
        uint32_t    count;
        float       rate;

        template<typename T>
        struct init_valueT{
            T minv, maxv;
            uint8_t interp_type;
            T get(float t) const {
                if (interp_type == 0){
                    return minv;
                }
                if (interp_type == 1)
                    return glm::lerp(minv, maxv, t);

                assert(false && "not implement");
                return minv;
            }
        };

        template<typename T>
        struct interp_valueT{
            T scale;
            uint8_t interp_type;

            void from_init_value(const init_valueT<T>& iv) {
                scale = (iv.maxv - iv.minv) / float(particles::life::MAX_PROCESS);
                interp_type = iv.interp_type;
            }

            T get(const T&value, uint32_t delta) const {
                if (interp_type == 0)
                    return scale;
                if (interp_type == 1)
                    return ((float)delta * scale + value);
                assert(false && "not implement");
                return scale;
            }
        };

        template<typename T>
        struct color_attributeT{
            T rgba[4];
        };

        struct init_attributes{
            init_valueT<float>                      life;
            init_valueT<glm::vec3>                  velocity;
            init_valueT<glm::vec3>                  acceleration;
            init_valueT<glm::vec3>                  scale;
            init_valueT<glm::vec3>                  translation;
            init_valueT<glm::vec3>                  rotation;
            init_valueT<glm::vec2>                  uv_motion;
            color_attributeT<init_valueT<float>>    color;
            materialdata                            material;
            comp_ids components;
        };

        struct interp_attributes{
            interp_valueT<glm::vec3>                  velocity;
            interp_valueT<glm::vec3>                  acceleration;
            interp_valueT<glm::vec3>                  scale;
            interp_valueT<glm::vec3>                  translation;
            interp_valueT<glm::vec3>                  rotation;
            interp_valueT<glm::vec2>                  uv_motion;
            color_attributeT<interp_valueT<float>>    color;
            comp_ids components;
        };

        init_attributes     init;
        interp_attributes   interp;
    };

    using life                       = componentT<lifedata,       ID_life>;
    using spawn                      = componentT<spawndata,      ID_spawn>;
    using velocity                   = componentT<glm::vec3,      ID_velocity>;
    using acceleration               = componentT<glm::vec3,      ID_acceleration>;
    using scale                      = componentT<glm::vec3,      ID_scale>;
    using rotation                   = componentT<glm::quat,      ID_rotation>;
    using translation                = componentT<glm::vec3,      ID_translation>;
    using uv_motion                  = componentT<glm::vec2,      ID_uv_motion>;
    using quad                       = componentT<quaddata,       ID_quad>; // make pos/uv/color in one component for render purpose
    using material                   = componentT<materialdata,   ID_material>;

    using f3_interpolator           = spawndata::interp_valueT<glm::vec3>;
    using f2_interpolator           = spawndata::interp_valueT<glm::vec2>;
    using velocity_interpolator     = componentT<f3_interpolator, ID_velocity_interpolator>;
    using acceleration_interpolator = componentT<f3_interpolator, ID_acceleration_interpolator>;
    using scale_interpolator        = componentT<f3_interpolator, ID_scale_interpolator>;
    //using rotation_interpolator     = componentT<glm::quat,       ID_rotation_interpolator>;
    using translation_interpolator  = componentT<f3_interpolator, ID_translation_interpolator>;
    using uv_motion_interpolator    = componentT<f2_interpolator, ID_uv_motion>;
    using color_interpolator        = componentT<spawndata::color_attributeT<spawndata::interp_valueT<float>>,    ID_color_interpolator>;
};

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

    void spawn_particles(uint32_t spawnnum, uint32_t spawnidx, const particles::spawn &sd);
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


    void print_particles_status();

private:
    particles mparticles;
    struct particle_manager *mmgr;

    render_data mrenderdata;
    std::array<component_array *, ID_component_count> mcomp_arrays;
};