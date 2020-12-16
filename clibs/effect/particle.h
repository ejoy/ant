#pragma once

#include "quadcache.h"
enum component_id : uint32_t {
    ID_life = 0,
    ID_spawn,
    ID_velocity,
    ID_acceleration,
    ID_scale,
    ID_rotation,
    ID_translation,
    ID_color,
    ID_uv,
    ID_uv_motion,
    ID_subuv,
    ID_material,

    ID_key_count,

    ID_interpolator_start = ID_key_count,
    ID_velocity_interpolator = ID_interpolator_start,
    ID_acceleration_interpolator,
    ID_scale_interpolator,
    ID_rotation_interpolator,
    ID_translation_interpolator,
    ID_uv_motion_interpolator,
    ID_color_interpolator,
    ID_subuv_index_interpolator,
    ID_interpolator_end,

    ID_component_count = ID_interpolator_end,
    ID_TAG_emitter = ID_component_count,
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

struct lifedata {
    static inline const float   FREQUENCY = 1 / 60.f;
    static const uint32_t       MAX_PROCESS_BITS = 10;
    static const uint32_t       MAX_TICK_BITS = 22;
    static const uint32_t       MAX_PROCESS = pow(2, MAX_PROCESS_BITS);

    static inline uint32_t time2tick(float t_in_second) {
        return uint32_t(t_in_second / FREQUENCY + 0.5 / FREQUENCY);
    }

    inline uint32_t which_process(float t_in_second) const {
        return uint32_t((time2tick(t_in_second) / float(tick)) * MAX_PROCESS);
    }

    inline uint32_t delta_process(float dt) const {
        return which_process(current + dt) - process;
    }

    inline bool isdead() const { return process >= tick; }
    inline bool update(float dt) { current += dt; return update_process(); }
    inline bool update_process() {
        process = which_process(current);
        return isdead();
    }

    inline float normalize_process() const {
        return (process / float(MAX_PROCESS));
    }

    lifedata(uint32_t t) : tick(t), process(0), current(0.f) {}
    lifedata(float t) : tick(time2tick(t)), process(0), current(0.f) {}
    lifedata() : tick(0), process(0), current(0.f) {}
    void set(float t) { tick = time2tick(t); process = 0; current = 0.f; }
    uint32_t tick : MAX_TICK_BITS;
    uint32_t process : MAX_PROCESS_BITS;
    float    current;
};

namespace interpolation{
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
            scale = T((iv.maxv - iv.minv) / float(lifedata::MAX_PROCESS));
            interp_type = iv.interp_type;
        }

        T get(const T&value, uint32_t delta) const {
            if (interp_type == 0)
                return scale;
            if (interp_type == 1)
                return (T(float(delta) * scale) + value);
            assert(false && "not implement");
            return scale;
        }
    };

    template<typename T>
    struct color_attributeT{
        T rgba[4];
    };

    using f3_init_value         = init_valueT<glm::vec3>;
    using f2_init_value         = init_valueT<glm::vec2>;
    using color_init_value      = color_attributeT<init_valueT<float>>;

    using f3_interpolator       = interp_valueT<glm::vec3>;
    using f2_interpolator       = interp_valueT<glm::vec2>;
    using u16_interpolator      = interp_valueT<uint16_t>;
    using color_interpolator    = color_attributeT<interp_valueT<float>>;
}

template<typename T, component_id COMP_ID>
struct componentT : public T {
    using T::T;
    componentT(const T&t) : T(t){}
    static constexpr component_id ID() { return COMP_ID; }
};

struct materialdata {
    uint8_t idx;
};

struct subuvdata{
    glm::ivec2 dimension;
    uint16_t index;
};

struct quad_location {
    glm::vec3 v[4];
};

struct quad_uv {
    glm::vec2 uv[4];
};

struct particle_manager;
class component_array;
struct particles{
    using life                      = componentT<lifedata,       ID_life>;
    using velocity                  = componentT<glm::vec3,      ID_velocity>;
    using acceleration              = componentT<glm::vec3,      ID_acceleration>;
    using scale                     = componentT<glm::vec3,      ID_scale>;
    using rotation                  = componentT<glm::quat,      ID_rotation>;
    using translation               = componentT<glm::vec3,      ID_translation>;
    using color                     = componentT<glm::u8vec4,    ID_color>;
    using uv                        = componentT<quad_uv,        ID_uv>;
    using uv_motion                 = componentT<glm::vec2,      ID_uv_motion>;
    using subuv                     = componentT<subuvdata,      ID_subuv>;
    using material                  = componentT<materialdata,   ID_material>;

    using velocity_interpolator     = componentT<interpolation::f3_interpolator, ID_velocity_interpolator>;
    using acceleration_interpolator = componentT<interpolation::f3_interpolator, ID_acceleration_interpolator>;
    using scale_interpolator        = componentT<interpolation::f3_interpolator, ID_scale_interpolator>;
    using translation_interpolator  = componentT<interpolation::f3_interpolator, ID_translation_interpolator>;
    using uv_motion_interpolator    = componentT<interpolation::f2_interpolator, ID_uv_motion>;
    using subuv_index_interpolator  = componentT<interpolation::u16_interpolator, ID_subuv_index_interpolator>;
    using color_interpolator        = componentT<interpolation::color_interpolator, ID_color_interpolator>;

    particles();
    ~particles();
    template<typename T>
    std::vector<T>& data();

    void pop_back(const comp_ids &ids);
    template<typename T>
    component_id add_component(const T &v){ data<T>().push_back(v); return T::ID(); }

    template<typename T>
    T& component_value(int idx = -1) {auto &d = data<T>(); return (idx < 0) ? d.back() : d[idx];}

    void remap_particles(struct particle_manager *pm);
private:
    template<typename T>
    void create_array();
    std::array<component_array *, ID_component_count> mcomp_arrays;
};