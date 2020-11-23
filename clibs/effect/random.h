#pragma once

class randomobj final{
    randomobj(float minv, float maxv) 
        : mgen(std::random_device().operator()())
        , mdis(minv, maxv)
        {}
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

class randomobj_vec3 final {
public:
    randomobj_vec3(const glm::vec3 &minv, const glm::vec3 &maxv)
        : x(randomobj::create(minv[0], maxv[0]))
        , y(randomobj::create(minv[1], maxv[1]))
        , z(randomobj::create(minv[2], maxv[2]))
        {}

    glm::vec3 operator()(){
        return glm::vec3(x.operator()(), y.operator()(), z.operator()());
    }
private:
    randomobj x, y, z;
};
