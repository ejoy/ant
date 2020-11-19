#pragma once

class randomobj final{
    randomobj(float minv, float maxv) : mgen(std::random_device().operator()()){}
    std::mt19937 mgen;
    std::uniform_real_distribution<float> mdis;
public:
    float operator()() {
        return mdis(mgen);
    }
    static randomobj&& create(float minv, float maxv) {
        return std::move(randomobj(minv, maxv));
    }

    static randomobj&& create(const glm::vec2 &range) {
        return create(range[0], range[1]);
    }
};
