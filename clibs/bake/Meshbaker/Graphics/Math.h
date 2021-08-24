#pragma once 
#include "glm/glm.hpp"
#include <random>

namespace Graphics {
inline void SphericalToCartesianXYZYUP(float r, float theta, float phi, glm::vec3& xyz){
    xyz.x = r * std::cosf(phi) * std::sinf(theta);
    xyz.y = r * std::cosf(theta);
    xyz.z = r * std::sinf(theta) * std::sinf(phi);
}

class Random {
public:
    void SetSeed(uint32_t seed){
        engine.seed(seed);
    }
    void SeedWithRandomValue(){
        std::random_device device;
        engine.seed(device());
    }

    uint32_t RandomUint(){
        return engine();
    }
    float RandomFloat(){
        return (RandomUint() & 0xFFFFFF) / float(1 << 24);
    }
    glm::vec2 RandomFloat2(){
        return glm::vec2(RandomFloat(), RandomFloat());
    }

private:

    std::mt19937 engine;
    std::uniform_real_distribution<float> distribution;
};
}
