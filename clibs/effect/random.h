#pragma once

class randomobj final{

    std::mt19937 mgen;
    std::uniform_real_distribution<float> mdis;
public:
    randomobj(float minv, float maxv) 
        : mgen(std::random_device().operator()())
        , mdis(minv, maxv)
        {}
    float operator()() {
        return mdis(mgen);
    }
};

class randomobj_v3 final {
public:
    randomobj_v3(const float *lhs, const float *rhs)
        : x(std::min(lhs[0], rhs[0]), std::max(lhs[0], rhs[0]))
        , y(std::min(lhs[1], rhs[1]), std::max(lhs[1], rhs[1]))
        , z(std::min(lhs[2], rhs[2]), std::max(lhs[2], rhs[2]))
        {}

    glm::vec3 operator()(){
        return glm::vec3(x(), y(), z());
    }
private:
    randomobj x, y, z;
};

class randomobj_v4 final {
public:
    randomobj_v4(const float *lhs, const float *rhs)
        : x(std::min(lhs[0], rhs[0]), std::max(lhs[0], rhs[0]))
        , y(std::min(lhs[1], rhs[1]), std::max(lhs[1], rhs[1]))
        , z(std::min(lhs[2], rhs[2]), std::max(lhs[2], rhs[2]))
        , w(std::min(lhs[3], rhs[3]), std::max(lhs[3], rhs[3]))
        {}

    glm::vec4 operator()(){
        return glm::vec4(x(), y(), z(), w());
    }
private:
    randomobj x, y, z, w;
};
