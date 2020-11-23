#pragma once

#include "interpolation.h"
#include "particle.h"
class transform{
public:
    virtual bool init(const particles_set &ps) = 0;
    virtual bool update(const particles_set &ps, float deltatime) = 0;
};

class scale_transform : public transform {
public:
    scale_transform(const interpolation<glm::vec3> *interpolate)
    : minterpolate(interpolate)
    {}

    virtual bool init(const particles_set &ps) override { return true;}
    virtual bool update(const particles_set &ps, float deltatime) override;
private:
    const interpolation<glm::vec3>  *minterpolate;
};

class rotation_transform : public transform {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class translation_transform : public transform {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class uv_transform : public transform {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class color_transform : public transform {
public:
    virtual bool init(const particles_set &ps) override;
    virtual bool update(const particles_set &ps, float deltatime) override;
};

class velocity_transform : public transform {
public:

};

class acceleration_transform : public transform {
public:
};