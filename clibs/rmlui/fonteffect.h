#pragma once

#include "context.h"
#include <RmlUi/Core.h>
#include <RmlUi/Core/FontEffect.h>
#include <iomanip>
#include <sstream>
#include <cassert>

struct rml_context;
class FontEffectInstancerManager{
public:
	Rml::FontEffectInstancer* Create(const Rml::String &name, const rml_context *c);
	~FontEffectInstancerManager(){
		for (auto it : mInstancers){
			delete it.second;
		}
		mInstancers.clear();
	}
private:
	std::unordered_map<Rml::String, Rml::FontEffectInstancer*>	mInstancers;
};

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
    uint16_t GetTexID() const { return mTexID; }
    FontEffectType GetType()  const { return mFEType;}
    virtual Rml::String GenerateKey() const = 0;
    virtual bool GetProperties(const shader &s, PropertyMap &properties, uint16_t &prog) const{
        Property m;
        m.value[0] = s.font_mask;
        m.value[1] = s.font_range;
        m.value[2] = m.value[3] = 0.0f;
        const char* mask = "u_mask";
        m.uniform_idx = s.font.find_uniform(mask);
        properties[mask] = m;

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


private:
    const uint16_t          mTexID;
    const FontEffectType    mFEType;
};

///default//////////////////////////////////////////////////////////////////
class SDFFontEffectDefault : public SDFFontEffect{
public:
    SDFFontEffectDefault(uint16_t fontid, bool simpletex = false) : SDFFontEffect(fontid, simpletex ? FE_None : FE_FontTex){}
    virtual Rml::String GenerateKey() const override {
        return DEFAULT_FONT_TEX_NAME;
    }
};

///outline//////////////////////////////////////////////////////////////////
class SDFFontEffectOutline : public SDFFontEffect{
public:
    SDFFontEffectOutline(uint16_t fontid, float w, Rml::Colourb c) 
    : SDFFontEffect(fontid, FontEffectType(FE_Outline|FE_FontTex))
    , width(w){
        SetLayer(Layer::Back);
        SetColour(c);
    }
    virtual bool HasUniqueTexture() const override{ return false;}
    virtual bool GetGlyphMetrics(Rml::Vector2i& origin, Rml::Vector2i& dimensions, const Rml::FontGlyph& glyph) const override{
        if (dimensions.x * dimensions.y > 0){
            origin.x      += int(width);
            origin.y      += int(width);
            dimensions.x  += int(2 * width);
            dimensions.y  += int(2 * width);
            return true;
        }

        return false;
    }

    float GetWidth() const {return width;}
    virtual Rml::String GenerateKey() const override{
        std::ostringstream oss;
        
        oss << std::setprecision(std::numeric_limits<long double>::digits10 + 1) 
            << DEFAULT_FONT_TEX_NAME.c_str() << GetType()<< width << GetColour();
        return oss.str();
    }

    virtual bool GetProperties(const shader &s, PropertyMap &properties, uint16_t &prog) const override {
        SDFFontEffect::GetProperties(s, properties, prog);
        assert(properties.find("u_mask") != properties.end());
#define MAX_FONT_GLYPH_SIZE 32
        const float texel = 1.f / MAX_FONT_GLYPH_SIZE;
        auto &m = properties["u_mask"];
        m.value[2] = s.font_mask+texel;
        m.value[3] = width * 4 * texel;

        Property color;
        tocolor(GetColour(), color.value);
        const char* colorname = "u_effect_color";
        color.uniform_idx = s.font_outline.find_uniform("u_effect_color");
        properties[colorname] = color;

        prog = s.font_outline.prog;

        return true;
    }

private:
    const float width;
};

class SDFFontEffectOulineInstancer : public Rml::FontEffectInstancer{
public:
    SDFFontEffectOulineInstancer(const rml_context *c)
        : mcontext(c)
        , id_width(Rml::PropertyId::Invalid)
        , id_color(Rml::PropertyId::Invalid)
    {
        id_width = RegisterProperty("width", "1px", true).AddParser("length").GetId();
        id_color = RegisterProperty("color", "white", false).AddParser("color").GetId();
        RegisterShorthand("font-effect", "width, color", Rml::ShorthandType::FallThrough);
    }

    Rml::SharedPtr<Rml::FontEffect> InstanceFontEffect(const Rml::String& RMLUI_UNUSED_PARAMETER(name), const Rml::PropertyDictionary& properties) override
    {
        RMLUI_UNUSED(name);

        const float width = properties.GetProperty(id_width)->Get<float>();
        const Rml::Colourb color = properties.GetProperty(id_color)->Get<Rml::Colourb>();

        return Rml::MakeShared<SDFFontEffectOutline>(mcontext->font_tex.texid, width, color);
    }
private:
    const rml_context *mcontext;
    Rml::PropertyId id_width, id_color;
};

///shadow//////////////////////////////////////////////////////////////////