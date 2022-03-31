#pragma once

#include "context.h"
extern "C"{
    #include "../font/font_manager.h"
}
#include <iomanip>
#include <sstream>
#include <cassert>

struct RmlContext;

enum class FontEffect {
    None,
    Outline,
    Shadow,
    Image,
};

struct Property{
    uint16_t uniform_idx;
    union {
        float value[4];
        struct {
            uint8_t stage;
            uint16_t texid;
        };
    };
};

using PropertyMap = std::unordered_map<std::string, Property>;

static const std::string DEFAULT_FONT_TEX_NAME("?FONT_TEX");

class SDFFontEffect {
public:
    SDFFontEffect(uint16_t texid, int8_t eo, FontEffect t)
        : mTexID(texid)
        , mFEType(t)
        , mEdgeValueOffset(eo)
        , mDistMultiplier(1.f)
    {}
    virtual ~SDFFontEffect() {}
    
    uint16_t GetTexID() const           { return mTexID; }
    FontEffect GetType()  const     { return mFEType;}

    float GetDistMultiplier() const     { return mDistMultiplier; }
    void SetDistMultiplier(float d)     { mDistMultiplier = d;}

    int8_t GetEdgeValueOffset() const  { return mEdgeValueOffset; }
    void SetEdgeValueOffset(int8_t e)  { mEdgeValueOffset = e; }

public:
    virtual std::string GenerateKey() const = 0;
    virtual bool GetProperties(struct font_manager* F, const shader_info &si, PropertyMap &properties) const{
        Property m;
        m.value[0] = F->font_manager_sdf_mask(F) - F->font_manager_sdf_distance(F, mEdgeValueOffset);
        m.value[1] = mDistMultiplier;
        m.value[2] = m.value[3] = 0.0f;
        const char* mn = "u_mask";
        m.uniform_idx = si.find_uniform(mn);
        if (m.uniform_idx != UINT16_MAX)
            properties[mn] = m;

        Property t;
        t.texid = GetTexID();
        t.stage = 0;
        const char* tex = "s_tex";
        t.uniform_idx = si.find_uniform(tex);
        if (t.uniform_idx != UINT16_MAX)
            properties[tex] = t;
        return true;
    }

public:
    static bool IsFontTexResource(const std::string &sroucename){
        return sroucename.find(DEFAULT_FONT_TEX_NAME) != std::string::npos;
    }

protected:
    static inline void
    tocolor(const Rml::Color &c, float *cc){
        cc[0] = c.r / 255.f;
        cc[1] = c.g / 255.f;
        cc[2] = c.b / 255.f;
        cc[3] = c.a / 255.f;
    }

    const shader_info&
    GetShaderInfo(const shader &s) const {
        switch (mFEType) {
        case FontEffect::Outline:       return s.font_outline;
        case FontEffect::Shadow:        return s.font_shadow;
        case FontEffect::None:          return s.font;
        default: assert(false &&"invalid"); return s.font;
        }
    }


private:
    const uint16_t          mTexID;
    const FontEffect        mFEType;
    int8_t mEdgeValueOffset;
    float mDistMultiplier;
};

///default//////////////////////////////////////////////////////////////////
class SDFFontEffectDefault : public SDFFontEffect{
public:
    SDFFontEffectDefault(uint16_t texid, bool simpletex = false) : SDFFontEffect(texid, 0, simpletex ? FontEffect::Image : FontEffect::None){}
    virtual std::string GenerateKey() const override {
        return DEFAULT_FONT_TEX_NAME;
    }
};

///outline//////////////////////////////////////////////////////////////////
class TSDFFontEffectOutline : public SDFFontEffect{
public:
    TSDFFontEffectOutline(uint16_t texid, float w, int8_t eo, Rml::Color c)
    : SDFFontEffect(texid, eo, FontEffect::Outline)
    , mWidth(w)
    , mcolor(c)
    { }

    virtual std::string GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << (int)GetType()<< mWidth
            << *(uint32_t*)&mcolor;
        return oss.str();
    }

    virtual bool GetProperties(struct font_manager* F, const shader_info &si, PropertyMap &properties) const override {
        SDFFontEffect::GetProperties(F, si, properties);
        auto itmask = properties.find("u_mask");
        if (itmask != properties.end()){
            auto &m = itmask->second;
            m.value[2] = mWidth;
        }

        Property color;
        tocolor(mcolor, color.value);
        const char* colorname = "u_effect_color";
        color.uniform_idx   = si.find_uniform("u_effect_color");
        if (color.uniform_idx != UINT16_MAX)
            properties[colorname] = color;
        return true;
    }

private:
    const float mWidth;
    Rml::Color mcolor;
};

///shadow//////////////////////////////////////////////////////////////////
class SDFFontEffectShadow : public SDFFontEffect{
public:
SDFFontEffectShadow(uint16_t texid, int8_t eo, const Rml::Point &offset, Rml::Color c)
    : SDFFontEffect(texid, eo, FontEffect::Shadow)
    , moffset(offset)
    , mcolor(c)
    { }

    Rml::Point GetOffset() const { return moffset; }
    virtual std::string GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << (int)GetType()<< moffset.x << moffset.y
            << *(uint32_t*)&mcolor;
        return oss.str();
    }

    virtual bool GetProperties(struct font_manager* F, const shader_info &si, PropertyMap &properties) const override {
        SDFFontEffect::GetProperties(F, si, properties);

        Property color;
        tocolor(mcolor, color.value);
        const char* colorname = "u_effect_color";
        color.uniform_idx = si.find_uniform(colorname);
        if (color.uniform_idx != UINT16_MAX)
            properties[colorname] = color;

        Property offset;
        const char* offsetname = "u_shadow_offset";
        offset.uniform_idx = si.find_uniform(offsetname);
        if (offset.uniform_idx != UINT16_MAX){
            offset.value[0] = moffset.x / FONT_MANAGER_TEXSIZE;
            offset.value[1] = moffset.y / FONT_MANAGER_TEXSIZE;
            offset.value[2] = offset.value[3] = 0.0f;
            properties[offsetname] = offset;
        }
        return true;
    }

private:
    const Rml::Point moffset;
    Rml::Color mcolor;
};
