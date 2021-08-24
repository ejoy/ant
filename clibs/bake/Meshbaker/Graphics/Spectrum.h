
/*
    pbrt source code is Copyright(c) 1998-2015
                        Matt Pharr, Greg Humphreys, and Wenzel Jakob.

    This file is part of pbrt.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are
    met:

    - Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.

    - Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
    IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
    TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
    PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
    HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
    SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
    DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
    THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
    (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

 */

#pragma once

#include "Constants.h"
#include "glm/glm.hpp"

#include <cstdio>
#include <ostream>
#include <cassert>
#include <vector>

namespace Graphics{
// Spectrum Utility Declarations
static const int SampledLambdaStart = 400;
static const int SampledLambdaEnd = 700;
static const int NumSpectralSamples = 60;
extern bool SpectrumSamplesSorted(const float *lambda, const float *vals,
                                  int n);
extern void SortSpectrumSamples(float *lambda, float *vals, int n);
extern float AverageSpectrumSamples(const float *lambda, const float *vals,
                                    int n, float lambdaStart, float lambdaEnd);
inline void XYZToRGB(const float xyz[3], float rgb[3]) {
    rgb[0] = 3.240479f * xyz[0] - 1.537150f * xyz[1] - 0.498535f * xyz[2];
    rgb[1] = -0.969256f * xyz[0] + 1.875991f * xyz[1] + 0.041556f * xyz[2];
    rgb[2] = 0.055648f * xyz[0] - 0.204043f * xyz[1] + 1.057311f * xyz[2];
}

inline void RGBToXYZ(const float rgb[3], float xyz[3]) {
    xyz[0] = 0.412453f * rgb[0] + 0.357580f * rgb[1] + 0.180423f * rgb[2];
    xyz[1] = 0.212671f * rgb[0] + 0.715160f * rgb[1] + 0.072169f * rgb[2];
    xyz[2] = 0.019334f * rgb[0] + 0.119193f * rgb[1] + 0.950227f * rgb[2];
}

enum class SpectrumType { Reflectance, Illuminant };
extern float InterpolateSpectrumSamples(const float *lambda, const float *vals,
                                        int n, float l);
extern void Blackbody(const float *lambda, int n, float T, float *Le);
extern void BlackbodyNormalized(const float *lambda, int n, float T,
                                float *vals);

// Spectral Data Declarations
static const int nCIESamples = 471;
extern const float CIE_X[nCIESamples];
extern const float CIE_Y[nCIESamples];
extern const float CIE_Z[nCIESamples];
extern const float CIE_lambda[nCIESamples];
static const float CIE_Y_integral = 106.856895f;
static const int nRGB2SpectSamples = 32;
extern const float RGB2SpectLambda[nRGB2SpectSamples];
extern const float RGBRefl2SpectWhite[nRGB2SpectSamples];
extern const float RGBRefl2SpectCyan[nRGB2SpectSamples];
extern const float RGBRefl2SpectMagenta[nRGB2SpectSamples];
extern const float RGBRefl2SpectYellow[nRGB2SpectSamples];
extern const float RGBRefl2SpectRed[nRGB2SpectSamples];
extern const float RGBRefl2SpectGreen[nRGB2SpectSamples];
extern const float RGBRefl2SpectBlue[nRGB2SpectSamples];
extern const float RGBIllum2SpectWhite[nRGB2SpectSamples];
extern const float RGBIllum2SpectCyan[nRGB2SpectSamples];
extern const float RGBIllum2SpectMagenta[nRGB2SpectSamples];
extern const float RGBIllum2SpectYellow[nRGB2SpectSamples];
extern const float RGBIllum2SpectRed[nRGB2SpectSamples];
extern const float RGBIllum2SpectGreen[nRGB2SpectSamples];
extern const float RGBIllum2SpectBlue[nRGB2SpectSamples];

// Forward declares
class RGBSpectrum;

// Utility functions
inline float SpectrumLerp(float t, float v1, float v2) { return (1 - t) * v1 + t * v2; }

// Spectrum Declarations
template <int nSpectrumSamples>
class CoefficientSpectrum {
  public:
    // CoefficientSpectrum Public Methods
    CoefficientSpectrum(float v = 0.f) {
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] = v;
        assert(!HasNaNs());
    }
#ifdef DEBUG
    CoefficientSpectrum(const CoefficientSpectrum &s) {
        assert(!s.HasNaNs());
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] = s.c[i];
    }

    CoefficientSpectrum &operator=(const CoefficientSpectrum &s) {
        assert(!s.HasNaNs());
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] = s.c[i];
        return *this;
    }
#endif  // DEBUG
    void Print(FILE *f) const {
        fprintf(f, "[ ");
        for (int i = 0; i < nSpectrumSamples; ++i) {
            fprintf(f, "%f", c[i]);
            if (i != nSpectrumSamples - 1) fprintf(f, ", ");
        }
        fprintf(f, "]");
    }
    CoefficientSpectrum &operator+=(const CoefficientSpectrum &s2) {
        assert(!s2.HasNaNs());
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] += s2.c[i];
        return *this;
    }
    CoefficientSpectrum operator+(const CoefficientSpectrum &s2) const {
        assert(!s2.HasNaNs());
        CoefficientSpectrum ret = *this;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] += s2.c[i];
        return ret;
    }
    CoefficientSpectrum operator-(const CoefficientSpectrum &s2) const {
        assert(!s2.HasNaNs());
        CoefficientSpectrum ret = *this;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] -= s2.c[i];
        return ret;
    }
    CoefficientSpectrum operator/(const CoefficientSpectrum &s2) const {
        assert(!s2.HasNaNs());
        CoefficientSpectrum ret = *this;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] /= s2.c[i];
        return ret;
    }
    CoefficientSpectrum operator*(const CoefficientSpectrum &sp) const {
        assert(!sp.HasNaNs());
        CoefficientSpectrum ret = *this;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] *= sp.c[i];
        return ret;
    }
    CoefficientSpectrum &operator*=(const CoefficientSpectrum &sp) {
        assert(!sp.HasNaNs());
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] *= sp.c[i];
        return *this;
    }
    CoefficientSpectrum operator*(float a) const {
        CoefficientSpectrum ret = *this;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] *= a;
        assert(!ret.HasNaNs());
        return ret;
    }
    CoefficientSpectrum &operator*=(float a) {
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] *= a;
        assert(!HasNaNs());
        return *this;
    }
    friend inline CoefficientSpectrum operator*(float a,
                                                const CoefficientSpectrum &s) {
        assert(!std::isnan(a) && !s.HasNaNs());
        return s * a;
    }
    CoefficientSpectrum operator/(float a) const {
        assert(!std::isnan(a));
        CoefficientSpectrum ret = *this;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] /= a;
        assert(!ret.HasNaNs());
        return ret;
    }
    CoefficientSpectrum &operator/=(float a) {
        assert(!std::isnan(a));
        for (int i = 0; i < nSpectrumSamples; ++i) c[i] /= a;
        return *this;
    }
    bool operator==(const CoefficientSpectrum &sp) const {
        for (int i = 0; i < nSpectrumSamples; ++i)
            if (c[i] != sp.c[i]) return false;
        return true;
    }
    bool operator!=(const CoefficientSpectrum &sp) const {
        return !(*this == sp);
    }
    bool IsBlack() const {
        for (int i = 0; i < nSpectrumSamples; ++i)
            if (c[i] != 0.) return false;
        return true;
    }
    friend CoefficientSpectrum Sqrt(const CoefficientSpectrum &s) {
        CoefficientSpectrum ret;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] = std::sqrt(s.c[i]);
        assert(!ret.HasNaNs());
        return ret;
    }
    template <int n>
    friend inline CoefficientSpectrum<n> Pow(const CoefficientSpectrum<n> &s,
                                             float e);
    CoefficientSpectrum operator-() const {
        CoefficientSpectrum ret;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] = -c[i];
        return ret;
    }
    friend CoefficientSpectrum Exp(const CoefficientSpectrum &s) {
        CoefficientSpectrum ret;
        for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] = std::exp(s.c[i]);
        assert(!ret.HasNaNs());
        return ret;
    }
    friend std::ostream &operator<<(std::ostream &os,
                                    const CoefficientSpectrum &s) {
        os << "[";
        for (int i = 0; i < nSpectrumSamples; ++i) {
            os << s.c[i];
            if (i + 1 < nSpectrumSamples) os << ", ";
        }
        os << "]";
        return os;
    }
    CoefficientSpectrum Clamp(float low = 0, float high = FloatInfinity) const {
        CoefficientSpectrum ret;
        for (int i = 0; i < nSpectrumSamples; ++i)
            ret.c[i] = glm::clamp(c[i], low, high);
        assert(!ret.HasNaNs());
        return ret;
    }
    bool HasNaNs() const {
        for (int i = 0; i < nSpectrumSamples; ++i)
            if (std::isnan(c[i])) return true;
        return false;
    }
    bool Write(FILE *f) const {
        for (int i = 0; i < nSpectrumSamples; ++i)
            if (fprintf(f, "%f ", c[i]) < 0) return false;
        return true;
    }
    bool Read(FILE *f) {
        for (int i = 0; i < nSpectrumSamples; ++i) {
            double v;
            if (fscanf(f, "%lf ", &v) != 1) return false;
            c[i] = v;
        }
        return true;
    }
    float &operator[](int i) { return c[i]; }
    float operator[](int i) const { return c[i]; }

    // CoefficientSpectrum Public Data
    static const int nSamples = nSpectrumSamples;

  protected:
    // CoefficientSpectrum Protected Data
    float c[nSpectrumSamples];
};

class SampledSpectrum : public CoefficientSpectrum<NumSpectralSamples> {
  public:
    // SampledSpectrum Public Methods
    SampledSpectrum(float v = 0.f) : CoefficientSpectrum(v) {}
    SampledSpectrum(const CoefficientSpectrum<NumSpectralSamples> &v)
        : CoefficientSpectrum<NumSpectralSamples>(v) {}
    static SampledSpectrum FromSampled(const float *lambda, const float *v,
                                       int n) {
        // Sort samples if unordered, use sorted for returned spectrum
        if (!SpectrumSamplesSorted(lambda, v, n)) {
            std::vector<float> slambda(&lambda[0], &lambda[n]);
            std::vector<float> sv(&v[0], &v[n]);
            SortSpectrumSamples(&slambda[0], &sv[0], n);
            return FromSampled(&slambda[0], &sv[0], n);
        }
        SampledSpectrum r;
        for (int i = 0; i < NumSpectralSamples; ++i) {
            // Compute average value of given SPD over $i$th sample's range
            float lambda0 = SpectrumLerp(float(i) / float(NumSpectralSamples),
                                 float(SampledLambdaStart), float(SampledLambdaEnd));
            float lambda1 = SpectrumLerp(float(i + 1) / float(NumSpectralSamples),
                                 float(SampledLambdaStart), float(SampledLambdaEnd));
            r.c[i] = AverageSpectrumSamples(lambda, v, n, lambda0, lambda1);
        }
        return r;
    }
    static void Init() {
        // Compute XYZ matching functions for _SampledSpectrum_
        for (int i = 0; i < NumSpectralSamples; ++i) {
            float wl0 = SpectrumLerp(float(i) / float(NumSpectralSamples),
                             float(SampledLambdaStart), float(SampledLambdaEnd));
            float wl1 = SpectrumLerp(float(i + 1) / float(NumSpectralSamples),
                             float(SampledLambdaStart), float(SampledLambdaEnd));
            X.c[i] = AverageSpectrumSamples(CIE_lambda, CIE_X, nCIESamples, wl0,
                                            wl1);
            Y.c[i] = AverageSpectrumSamples(CIE_lambda, CIE_Y, nCIESamples, wl0,
                                            wl1);
            Z.c[i] = AverageSpectrumSamples(CIE_lambda, CIE_Z, nCIESamples, wl0,
                                            wl1);
        }

        // Compute RGB to spectrum functions for _SampledSpectrum_
        for (int i = 0; i < NumSpectralSamples; ++i) {
            float wl0 = SpectrumLerp(float(i) / float(NumSpectralSamples),
                             float(SampledLambdaStart), float(SampledLambdaEnd));
            float wl1 = SpectrumLerp(float(i + 1) / float(NumSpectralSamples),
                             float(SampledLambdaStart), float(SampledLambdaEnd));
            rgbRefl2SpectWhite.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBRefl2SpectWhite,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbRefl2SpectCyan.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBRefl2SpectCyan,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbRefl2SpectMagenta.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBRefl2SpectMagenta,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbRefl2SpectYellow.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBRefl2SpectYellow,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbRefl2SpectRed.c[i] = AverageSpectrumSamples(
                RGB2SpectLambda, RGBRefl2SpectRed, nRGB2SpectSamples, wl0, wl1);
            rgbRefl2SpectGreen.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBRefl2SpectGreen,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbRefl2SpectBlue.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBRefl2SpectBlue,
                                       nRGB2SpectSamples, wl0, wl1);

            rgbIllum2SpectWhite.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectWhite,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbIllum2SpectCyan.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectCyan,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbIllum2SpectMagenta.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectMagenta,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbIllum2SpectYellow.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectYellow,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbIllum2SpectRed.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectRed,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbIllum2SpectGreen.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectGreen,
                                       nRGB2SpectSamples, wl0, wl1);
            rgbIllum2SpectBlue.c[i] =
                AverageSpectrumSamples(RGB2SpectLambda, RGBIllum2SpectBlue,
                                       nRGB2SpectSamples, wl0, wl1);
        }
    }
    void ToXYZ(float xyz[3]) const {
        xyz[0] = xyz[1] = xyz[2] = 0.f;
        for (int i = 0; i < NumSpectralSamples; ++i) {
            xyz[0] += X.c[i] * c[i];
            xyz[1] += Y.c[i] * c[i];
            xyz[2] += Z.c[i] * c[i];
        }
        float scale = float(SampledLambdaEnd - SampledLambdaStart) /
                      float(CIE_Y_integral * NumSpectralSamples);
        xyz[0] *= scale;
        xyz[1] *= scale;
        xyz[2] *= scale;
    }
    float y() const {
        float yy = 0.f;
        for (int i = 0; i < NumSpectralSamples; ++i) yy += Y.c[i] * c[i];
        return yy * float(SampledLambdaEnd - SampledLambdaStart) /
               float(CIE_Y_integral * NumSpectralSamples);
    }
    void ToRGB(float rgb[3]) const {
        float xyz[3];
        ToXYZ(xyz);
        XYZToRGB(xyz, rgb);
    }

    glm::vec3 ToRGB() const {
        float rgb[3];
        ToRGB(rgb);
        return glm::vec3(rgb[0], rgb[1], rgb[2]);
    }

    RGBSpectrum ToRGBSpectrum() const;
    static SampledSpectrum FromRGB(
        const float rgb[3], SpectrumType type = SpectrumType::Illuminant);
    static SampledSpectrum FromRGB(
        glm::vec3 rgb, SpectrumType type = SpectrumType::Illuminant) {
        float rgbArray[3] = { rgb.x, rgb.y, rgb.z };
        return FromRGB(rgbArray, type);
    }
    static SampledSpectrum FromXYZ(
        const float xyz[3], SpectrumType type = SpectrumType::Reflectance) {
        float rgb[3];
        XYZToRGB(xyz, rgb);
        return FromRGB(rgb, type);
    }
    SampledSpectrum(const RGBSpectrum &r,
                    SpectrumType type = SpectrumType::Reflectance);

  private:
    // SampledSpectrum Private Data
    static SampledSpectrum X, Y, Z;
    static SampledSpectrum rgbRefl2SpectWhite, rgbRefl2SpectCyan;
    static SampledSpectrum rgbRefl2SpectMagenta, rgbRefl2SpectYellow;
    static SampledSpectrum rgbRefl2SpectRed, rgbRefl2SpectGreen;
    static SampledSpectrum rgbRefl2SpectBlue;
    static SampledSpectrum rgbIllum2SpectWhite, rgbIllum2SpectCyan;
    static SampledSpectrum rgbIllum2SpectMagenta, rgbIllum2SpectYellow;
    static SampledSpectrum rgbIllum2SpectRed, rgbIllum2SpectGreen;
    static SampledSpectrum rgbIllum2SpectBlue;
};

class RGBSpectrum : public CoefficientSpectrum<3> {
    using CoefficientSpectrum<3>::c;

  public:
    // RGBSpectrum Public Methods
    RGBSpectrum(float v = 0.f) : CoefficientSpectrum<3>(v) {}
    RGBSpectrum(const CoefficientSpectrum<3> &v) : CoefficientSpectrum<3>(v) {}
    RGBSpectrum(const RGBSpectrum &s,
                SpectrumType type = SpectrumType::Reflectance) {
        *this = s;
    }
    static RGBSpectrum FromRGB(const float rgb[3],
                               SpectrumType type = SpectrumType::Reflectance) {
        RGBSpectrum s;
        s.c[0] = rgb[0];
        s.c[1] = rgb[1];
        s.c[2] = rgb[2];
        assert(!s.HasNaNs());
        return s;
    }
    void ToRGB(float *rgb) const {
        rgb[0] = c[0];
        rgb[1] = c[1];
        rgb[2] = c[2];
    }
    const RGBSpectrum &ToRGBSpectrum() const { return *this; }
    void ToXYZ(float xyz[3]) const { RGBToXYZ(c, xyz); }
    static RGBSpectrum FromXYZ(const float xyz[3],
                               SpectrumType type = SpectrumType::Reflectance) {
        RGBSpectrum r;
        XYZToRGB(xyz, r.c);
        return r;
    }
    float y() const {
        const float YWeight[3] = {0.212671f, 0.715160f, 0.072169f};
        return YWeight[0] * c[0] + YWeight[1] * c[1] + YWeight[2] * c[2];
    }
    static RGBSpectrum FromSampled(const float *lambda, const float *v, int n) {
        // Sort samples if unordered, use sorted for returned spectrum
        if (!SpectrumSamplesSorted(lambda, v, n)) {
            std::vector<float> slambda(&lambda[0], &lambda[n]);
            std::vector<float> sv(&v[0], &v[n]);
            SortSpectrumSamples(&slambda[0], &sv[0], n);
            return FromSampled(&slambda[0], &sv[0], n);
        }
        float xyz[3] = {0, 0, 0};
        for (int i = 0; i < nCIESamples; ++i) {
            float val = InterpolateSpectrumSamples(lambda, v, n, CIE_lambda[i]);
            xyz[0] += val * CIE_X[i];
            xyz[1] += val * CIE_Y[i];
            xyz[2] += val * CIE_Z[i];
        }
        float scale = float(CIE_lambda[nCIESamples - 1] - CIE_lambda[0]) /
                      float(CIE_Y_integral * nCIESamples);
        xyz[0] *= scale;
        xyz[1] *= scale;
        xyz[2] *= scale;
        return FromXYZ(xyz);
    }
};

// Spectrum Inline Functions
template <int nSpectrumSamples>
inline CoefficientSpectrum<nSpectrumSamples> Pow(
    const CoefficientSpectrum<nSpectrumSamples> &s, float e) {
    CoefficientSpectrum<nSpectrumSamples> ret;
    for (int i = 0; i < nSpectrumSamples; ++i) ret.c[i] = std::pow(s.c[i], e);
    assert(!ret.HasNaNs());
    return ret;
}

inline RGBSpectrum Lerp(float t, const RGBSpectrum &s1, const RGBSpectrum &s2) {
    return (1 - t) * s1 + t * s2;
}
}