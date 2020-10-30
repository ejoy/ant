#pragma once

#include "texture.h"
#include <RmlUi/Core.h>
#include <RmlUi/Core/FontEffect.h>

#include <sstream>

class FontEffectInstancerManager{
public:
	Rml::FontEffectInstancer* Create(const Rml::String &name);
	~FontEffectInstancerManager(){
		for (auto it : mInstancers){
			delete it.second;
		}
		mInstancers.clear();
	}
private:
	std::unordered_map<Rml::String, Rml::FontEffectInstancer*>	mInstancers;
};

///outline//////////////////////////////////////////////////////////////////
class SDFFontEffect : public Rml::FontEffect {
public:
    SDFFontEffect(TexDataFlag t) : mFEType(t){}
    TexDataFlag GetType()  const { return mFEType;}
    virtual Rml::String GenerateKey(const Rml::String &basename) = 0;
    virtual TexData* CreateTexData(uint16_t texid) = 0;
private:
    TexDataFlag mFEType;
};


class SDFFontEffectOutline : public SDFFontEffect{
public:
    SDFFontEffectOutline(uint16_t w, Rml::Colourb c) 
    : SDFFontEffect(TDF_FontEffect_Outline)
    , width(w){
        SetLayer(Layer::Back);
        SetColour(c);
    }
    virtual bool HasUniqueTexture() const override{ return false;}
    virtual bool GetGlyphMetrics(Rml::Vector2i& origin, Rml::Vector2i& dimensions, const Rml::FontGlyph& glyph) const override{
        if (dimensions.x * dimensions.y > 0){
            const uint16_t w = 2 * width;
            dimensions.x += w;
            dimensions.y += w;
            return true;
        }

        return false;
    }

    uint16_t GetWidth() const {return width;}
    virtual Rml::String GenerateKey(const Rml::String &basekey) override{
        std::ostringstream oss;
        oss << basekey.c_str() << GetType() << width << GetColour();
        return oss.str();
    }

    virtual TexData* CreateTexData(uint16_t texid) override{
        return new OutlineData(texid, TDF_FontEffect_Outline, width, GetColour());
    }
private:
    const uint16_t width;
};

class SDFFontEffectOulineInstancer : public Rml::FontEffectInstancer{
public:
    SDFFontEffectOulineInstancer() : 
        id_width(Rml::PropertyId::Invalid), id_color(Rml::PropertyId::Invalid)
    {
        id_width = RegisterProperty("width", "1px", true).AddParser("length").GetId();
        id_color = RegisterProperty("color", "white", false).AddParser("color").GetId();
        RegisterShorthand("font-effect", "width, color", Rml::ShorthandType::FallThrough);
    }

    Rml::SharedPtr<Rml::FontEffect> InstanceFontEffect(const Rml::String& RMLUI_UNUSED_PARAMETER(name), const Rml::PropertyDictionary& properties) override
    {
        RMLUI_UNUSED(name);

        const uint16_t width = uint16_t(properties.GetProperty(id_width)->Get<float>() + 0.5f);
        Rml::Colourb color = properties.GetProperty(id_color)->Get<Rml::Colourb>();

        return Rml::MakeShared<SDFFontEffectOutline>(width, color);
    }
private:
    Rml::PropertyId id_width, id_color;
};

///shadow//////////////////////////////////////////////////////////////////