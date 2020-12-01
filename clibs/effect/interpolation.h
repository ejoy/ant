#pragma once

enum interp_type : uint8_t {
    IT_linear = 0,
    IT_curve,
};

class interpolation {
public:
    virtual void process(uint32_t delta_tick, float &value) = 0;
    virtual interp_type get_type() const = 0;
};

class linear_interpolation : public interpolation {
public:
    linear_interpolation(float minv, float maxv, uint32_t maxprocess)
        : mprocess_step((maxv-minv) / float(maxprocess))
        {}

    virtual interp_type get_type() const {return IT_linear;}

    virtual void process(uint32_t delta_tick, float &value) override {
        value += mprocess_step * delta_tick;
    }
private:
    const float mprocess_step;
};