#pragma once

#include "particle.h"
class attribute{
public:
    virtual bool init(const particles_set &ps) = 0;
    virtual bool update(const particles_set &ps, float deltatime) = 0;
};

template<typename T>
class interpolation{
public:
    virtual T interpolate(float t) const = 0;
    struct range { T minv, maxv;};
    virtual range interpolate_range() const = 0;
};

template<typename T>
class linear_interpolation : public interpolation<T> {
public:
    linear_interpolation(const T& minv, const T& maxv):mminv(minv), mmaxv(maxv){}
    virtual T interpolate(float t) const override{
        return glm::lerp(mminv, mmaxv, t);
    }

    virtual interpolation<T>::range interpolate_range() const override {
        return {mminv, mmaxv};
    }

private:
    const T mminv, mmaxv;
};

class scale_attribute : public attribute {
public:
    scale_attribute(const interpolation<glm::vec3> *interpolate)
    : minterpolate(interpolate)
    {}

    virtual bool init(const particles_set &ps) override { return true;}
    virtual bool update(const particles_set &ps, float deltatime) override;
private:
    const interpolation<glm::vec3>  *minterpolate;
};

class rotation_attribute : public attribute {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class translation_attribute : public attribute {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class uv_attribute : public attribute {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class color_attribute : public attribute {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};