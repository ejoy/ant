#pragma once
#include "interpolation.h"

template<typename T>
struct linear_interp_attrib{
    T minv, maxv;
};

using v3_interp_attrib      = linear_interp_attrib<glm::vec3>;
using float_interp_attrib   = linear_interp_attrib<float>;

template<typename T>
struct component_attrib{
    interp_type type;
    union {
        linear_interp_attrib<T> linear_attrib;
    };
};

using v3_componet_attrib    = component_attrib<glm::vec3>;
using float_componet_attrib = component_attrib<float>;

using lifetime_attrib       = float_componet_attrib;

using velocity_attrib       = v3_componet_attrib;
using scale_attrib          = v3_componet_attrib;
using translation_attrib    = v3_componet_attrib;
using color_attrib          = v3_componet_attrib;


struct emitter_lifetime{
    float lifetime;
};