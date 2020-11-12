#pragma once

#include "context.h"
extern "C"{
    #include "font/font_manager.h"
}
#include <RmlUi/Core.h>
#include <RmlUi/Core/FontEffect.h>
#include <iomanip>
#include <sstream>
#include <cassert>

struct RmlContext;

enum FontEffectType : uint8_t {
    FE_None		= 0,
    FE_Outline	= 0x01,
    FE_Shadow 	= 0x02,
    FE_Glow 	= 0x04,
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

class SDFFontEffect : public Rml::FontEffect {
public:
    SDFFontEffect(uint16_t texid, FontEffectType t) : mTexID(texid), mFEType(t){}
    virtual bool HasUniqueTexture() const override{ return false;}
    uint16_t GetTexID() const { return mTexID; }
    FontEffectType GetType()  const { return mFEType;}
    virtual bool GetGlyphMetrics(Rml::Vector2i& origin, Rml::Vector2i& dimensions, const Rml::FontGlyph& glyph) const override final{ return false;}
    virtual Rml::String GenerateKey() const = 0;
    virtual bool GetProperties(struct font_manager* F, const shader &s, PropertyMap &properties, uint16_t &prog) const{
        const float mask = font_manager_sdf_mask(F, -5);
        const float range = font_manager_sdf_distance(F, 2.f);
        Property m;
        m.value[0] = mask;
        m.value[1] = range;
        m.value[2] = m.value[3] = 0.0f;
        const char* mn = "u_mask";
        m.uniform_idx = s.font.find_uniform(mn);
        properties[mn] = m;

        Property t;
        t.texid = GetTexID();
        t.stage = 0;
        const char* tex = "s_tex";
        t.uniform_idx = s.font.find_uniform(tex);
        properties[tex] = t;

        assert(t.uniform_idx == s.font_outline.find_uniform("s_tex"));
        assert(t.uniform_idx == s.font_shadow.find_uniform("s_tex"));
        assert(t.uniform_idx == s.font_glow.find_uniform("s_tex"));

        prog = s.font.prog;
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
        case (FE_Glow|FE_FontTex):          return s.font_glow;
        case (FE_Shadow|FE_FontTex):        return s.font_shadow;
        case (FE_FontTex):                  return s.font;
        default: assert(false &&"invalid"); return s.font;
        }
    }


private:
    const uint16_t          mTexID;
    const FontEffectType    mFEType;
};

///default//////////////////////////////////////////////////////////////////
class SDFFontEffectDefault : public SDFFontEffect{
public:
    SDFFontEffectDefault(uint16_t texid, bool simpletex = false) : SDFFontEffect(texid, simpletex ? FE_None : FE_FontTex){}
    virtual Rml::String GenerateKey() const override {
        return DEFAULT_FONT_TEX_NAME;
    }
};

///outline//////////////////////////////////////////////////////////////////
template<FontEffectType FE_TYPE>
class TSDFFontEffectOutline : public SDFFontEffect{
public:
    TSDFFontEffectOutline(uint16_t texid, float w, int mo, Rml::Colourb c) 
    : SDFFontEffect(texid, FE_TYPE)
    , mMaskOffset(mo)
    , mWidth(w){
        SetLayer(Layer::Back);
        SetColour(c);
    }

    virtual Rml::String GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << GetType()<< mWidth << GetColour();
        return oss.str();
    }

    virtual bool GetProperties(struct font_manager* F, const shader &s, PropertyMap &properties, uint16_t &prog) const override {
        SDFFontEffect::GetProperties(F, s, properties, prog);
        assert(properties.find("u_mask") != properties.end());
        auto &m = properties["u_mask"];

        m.value[0] = font_manager_sdf_mask(F, 0);
        m.value[1] = font_manager_sdf_distance(F, 0.5f);
        m.value[2] = font_manager_sdf_mask(F, mMaskOffset);
        m.value[3] = std::min(m.value[2], font_manager_sdf_distance(F, mWidth));

        Property color;
        tocolor(GetColour(), color.value);
        const char* colorname = "u_effect_color";
        const auto& si = GetShaderInfo(s);
        color.uniform_idx   = si.find_uniform("u_effect_color");
        properties[colorname] = color;

        prog = si.prog;

        return true;
    }

private:
    const int   mMaskOffset;
    const float mWidth;
};

static Rml::String
get_default_mask_offset_str(const struct font_manager* F){
    const int v = int(F->sdf.onedge_value * 0.85f);
    return std::to_string(v);
}

template<class FontEffectClass>
class TSDFFontEffectOulineInstancer : public Rml::FontEffectInstancer{
public:
    TSDFFontEffectOulineInstancer(const RmlContext* c)
        : mcontext(c)
        , id_width(Rml::PropertyId::Invalid)
        , id_color(Rml::PropertyId::Invalid)
        , id_maskoffset(Rml::PropertyId::Invalid)
    {
        id_width = RegisterProperty("width", "1px", true).AddParser("length").GetId();
        id_color = RegisterProperty("color", "white", false).AddParser("color").GetId();
        
        id_maskoffset = RegisterProperty("maskoffset", get_default_mask_offset_str(mcontext->font_mgr), false).AddParser("number").GetId();
        RegisterShorthand("font-effect", "width, color", Rml::ShorthandType::FallThrough);
        RegisterShorthand("font-effect", "width, color, maskoffset", Rml::ShorthandType::FallThrough);
    }

    Rml::SharedPtr<Rml::FontEffect> InstanceFontEffect(const Rml::String& RMLUI_UNUSED_PARAMETER(name), const Rml::PropertyDictionary& properties) override
    {
        RMLUI_UNUSED(name);

        const float width = properties.GetProperty(id_width)->Get<float>();
        const int offset = -std::abs(properties.GetProperty(id_maskoffset)->Get<int>());
        const Rml::Colourb color = properties.GetProperty(id_color)->Get<Rml::Colourb>();

        return Rml::MakeShared<FontEffectClass>(mcontext->font_tex.texid, width, offset, color);
    }
private:
    const RmlContext* mcontext;
    Rml::PropertyId id_width, id_color, id_maskoffset;
};

using SDFFontEffectOulineInstancer  = TSDFFontEffectOulineInstancer<TSDFFontEffectOutline<FontEffectType(FE_Outline|FE_FontTex)> >;
using SDFFontEffectGlowInstancer    = TSDFFontEffectOulineInstancer<TSDFFontEffectOutline<FontEffectType(FE_Glow|FE_FontTex)> >;

///shadow//////////////////////////////////////////////////////////////////
class SDFFontEffectShadow : public SDFFontEffect{
public:
SDFFontEffectShadow(uint16_t texid, int mo, const Rml::Vector2f &offset, Rml::Colourb c) 
    : SDFFontEffect(texid, FontEffectType(FE_Shadow|FE_FontTex))
    , mMaskOffset(mo)
    , moffset(offset)
    {
        SetLayer(Layer::Back);
        SetColour(c);
    }

    Rml::Vector2f GetOffset() const { return moffset; }
    virtual Rml::String GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << GetType()<< moffset.x << moffset.y << GetColour();
        return oss.str();
    }

    virtual bool GetProperties(struct font_manager* F, const shader &s, PropertyMap &properties, uint16_t &prog) const override {
        SDFFontEffect::GetProperties(F, s, properties, prog);
        assert(properties.find("u_mask") != properties.end());
        auto &m = properties["u_mask"];
        m.value[2] = font_manager_sdf_mask(F, mMaskOffset);
        m.value[3] = std::min(m.value[2], m.value[1]);


        Property color;
        tocolor(GetColour(), color.value);
        const char* colorname = "u_effect_color";
        color.uniform_idx = s.font_shadow.find_uniform(colorname);
        properties[colorname] = color;

        Property offset;
        const char* offsetname = "u_shadow_offset";
        offset.uniform_idx = s.font_shadow.find_uniform(offsetname);
        offset.value[0] = moffset.x;
        offset.value[1] = moffset.y;
        offset.value[2] = offset.value[3] = 0.0f;
        properties[offsetname] = offset;

        prog = s.font_shadow.prog;

        return true;
    }

private:
    const int mMaskOffset;
    const Rml::Vector2f moffset;
};

class SDFFontEffectShadowInstancer : public Rml::FontEffectInstancer{
public:
    SDFFontEffectShadowInstancer(const RmlContext*c)
        : mcontext(c)
        , id_offset_x(Rml::PropertyId::Invalid)
        , id_offset_y(Rml::PropertyId::Invalid)
        , id_color(Rml::PropertyId::Invalid)
        , id_maskoffset(Rml::PropertyId::Invalid)
    {
        id_offset_x = RegisterProperty("offset-x", "0px", true).AddParser("length").GetId();
        id_offset_y = RegisterProperty("offset-y", "0px", true).AddParser("length").GetId();
        id_color = RegisterProperty("color", "white", false).AddParser("color").GetId();
        id_maskoffset = RegisterProperty("maskoffset", get_default_mask_offset_str(mcontext->font_mgr), false).AddParser("number").GetId();
        
        RegisterShorthand("offset", "offset-x, offset-y", Rml::ShorthandType::FallThrough);
        RegisterShorthand("font-effect", "offset-x, offset-y, color", Rml::ShorthandType::FallThrough);
        RegisterShorthand("font-effect", "offset-x, offset-y, color, maskoffset", Rml::ShorthandType::FallThrough);
    }

    Rml::SharedPtr<Rml::FontEffect> InstanceFontEffect(const Rml::String& RMLUI_UNUSED_PARAMETER(name), const Rml::PropertyDictionary& properties) override
    {
        RMLUI_UNUSED(name);

        return Rml::MakeShared<SDFFontEffectShadow>(mcontext->font_tex.texid, 
                -abs(properties.GetProperty(id_maskoffset)->Get<int>()),
                Rml::Vector2f(  properties.GetProperty(id_offset_x)->Get<float>(),
                                properties.GetProperty(id_offset_y)->Get<float>()),
            properties.GetProperty(id_color)->Get<Rml::Colourb>());
    }
private:
    const RmlContext* mcontext;
    Rml::PropertyId id_maskoffset, id_offset_x, id_offset_y, id_color;
};

class FontEffectInstancerManager{
public:
	Rml::FontEffectInstancer* Create(const Rml::String &name, const RmlContext*c){
        auto it = mInstancers.find(name);
        if (it == mInstancers.end()){
            Rml::FontEffectInstancer *inst = nullptr;
            if (name == "outline"){
                inst = new SDFFontEffectOulineInstancer(c);
            } else if (name == "shadow"){
                inst = new SDFFontEffectShadowInstancer(c);
            } else if (name == "glow"){
                inst = new SDFFontEffectGlowInstancer(c);
            } else {
                assert(false && "invalid font effect name");
            }

            mInstancers[name] = inst;
            return inst;
        }
        return it->second;
    }
	~FontEffectInstancerManager(){
		for (auto it : mInstancers){
			delete it.second;
		}
		mInstancers.clear();
	}
private:
	std::unordered_map<Rml::String, Rml::FontEffectInstancer*>	mInstancers;
};