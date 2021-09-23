#pragma once

struct Scene;
struct LightData {
    Float3 pos;
    Float3 dir;

    Float3 color;
    float intensity;

    float range;
    float inner_cutoff;
    float outter_cutoff;
    float angular_radius;
    enum LightType {
        Directional = 0,
        Point = 1,
        Spot = 2,
        Area = 3,
    };
    LightType type;

    Float3 Luminance() const {
        return color * intensity;
    }

    Float3 Illuminance() const {
        float c = std::cos(angular_radius);
        auto integral = Pi * (1.0f - (c * c));
        return integral * Luminance();
    }
};

typedef std::vector<LightData>  Lights;