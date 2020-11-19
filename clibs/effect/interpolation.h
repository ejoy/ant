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