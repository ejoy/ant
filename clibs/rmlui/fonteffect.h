#pragma once

#include "context.h"
extern "C"{
    #include "../font/font_manager.h"
}
#include <iomanip>
#include <sstream>
#include <cassert>

struct RmlContext;

enum FontEffectType : uint8_t {
    FE_None		= 0,
    FE_Outline	= 0x01,
    FE_Shadow 	= 0x02,
    FE_FontTex  = 0x08,
};

struct Property{
    uint16_t uniform_idx;
    union {
        float value[4];
        struct {
            uint16_t stage;
            uint16_t texid;
        };
    };
};

using PropertyMap = std::unordered_map<Rml::String, Property>;

static const Rml::String DEFAULT_FONT_TEX_NAME("?FONT_TEX");

class SDFFontEffect {
public:
    SDFFontEffect(uint16_t texid, int8_t eo, FontEffectType t)
        : mTexID(texid)
        , mFEType(t)
        , mEdgeValueOffset(eo)
        , mDistMultiplier(1.f)
    {}
    
    uint16_t GetTexID() const           { return mTexID; }
    FontEffectType GetType()  const     { return mFEType;}

    float GetDistMultiplier() const     { return mDistMultiplier; }
    void SetDistMultiplier(float d)     { mDistMultiplier = d;}

    int8_t GetEdgeValueOffset() const  { return mEdgeValueOffset; }
    void SetEdgeValueOffset(int8_t e)  { mEdgeValueOffset = e; }

public:
    virtual Rml::String GenerateKey() const = 0;
    virtual bool GetProperties(struct font_manager* F, const shader_info &si, PropertyMap &properties) const{
        Property m;
        m.value[0] = font_manager_sdf_mask(F) - font_manager_sdf_distance(F, mEdgeValueOffset);
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
    static bool IsFontTexResource(const Rml::String &sroucename){
        return sroucename.find(DEFAULT_FONT_TEX_NAME) != Rml::String::npos;
    }

protected:
    static inline void
    tocolor(const Rml::Colourb &c, float *cc){
        cc[0] = c.red   / 256.f;
        cc[1] = c.green / 256.f;
        cc[2] = c.blue  / 256.f;
        cc[3] = c.alpha / 256.f;
    }

    const shader_info&
    GetShaderInfo(const shader &s) const {
        switch (uint16_t(mFEType)){
        case (FE_Outline|FE_FontTex):       return s.font_outline;
        case (FE_Shadow|FE_FontTex):        return s.font_shadow;
        case (FE_FontTex):                  return s.font;
        default: assert(false &&"invalid"); return s.font;
        }
    }


private:
    const uint16_t          mTexID;
    const FontEffectType    mFEType;
    int8_t mEdgeValueOffset;
    float mDistMultiplier;
};

///default//////////////////////////////////////////////////////////////////
class SDFFontEffectDefault : public SDFFontEffect{
public:
    SDFFontEffectDefault(uint16_t texid, bool simpletex = false) : SDFFontEffect(texid, 0, simpletex ? FE_None : FE_FontTex){}
    virtual Rml::String GenerateKey() const override {
        return DEFAULT_FONT_TEX_NAME;
    }
};

///outline//////////////////////////////////////////////////////////////////
template<FontEffectType FE_TYPE>
class TSDFFontEffectOutline : public SDFFontEffect{
public:
    TSDFFontEffectOutline(uint16_t texid, float w, int8_t eo, Rml::Colourb c) 
    : SDFFontEffect(texid, eo, FE_TYPE)
    , mWidth(w)
    , mcolor(c)
    { }

    virtual Rml::String GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << GetType()<< mWidth << mcolor;
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
    Rml::Colourb mcolor;
};

static Rml::String
get_default_mask_offset_str(struct font_manager* F){
    const int v = int(font_manager_sdf_mask(F) * 0.85f);
    return std::to_string(v);
}

///shadow//////////////////////////////////////////////////////////////////
class SDFFontEffectShadow : public SDFFontEffect{
public:
SDFFontEffectShadow(uint16_t texid, int8_t eo, const Rml::Point &offset, Rml::Colourb c) 
    : SDFFontEffect(texid, eo, FontEffectType(FE_Shadow|FE_FontTex))
    , moffset(offset)
    , mcolor(c)
    { }

    Rml::Point GetOffset() const { return moffset; }
    virtual Rml::String GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << GetType()<< moffset.x << moffset.y << mcolor;
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
    Rml::Colourb mcolor;
};
