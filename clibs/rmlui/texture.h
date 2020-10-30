#pragma once
#include <cstdint>
#include <RmlUi/Core/Types.h>
enum TexDataFlag : uint16_t {
    TDF_None                = 0,
    TDF_FontTex             = 0x0001,
    TDF_FontEffect_Mask     = 0x00F0,
    TDF_FontEffect_None		= 0x0000,
    TDF_FontEffect_Outline	= 0x0010,
    TDF_FontEffect_Shadow 	= 0x0020,
    TDF_FontEffect_Glow 	= 0x0040,
};

class TexData {
public:
    TexData(uint16_t texid, TexDataFlag flags = TDF_None) : mTexID(texid), mFlags(flags){}
    virtual ~TexData() {};
    uint16_t GetTexID() const { return mTexID; }
    TexDataFlag GetTextFlags() const { return mFlags; }

    static const TexData* ToTexData(Rml::TextureHandle th){
        return (TexData*)(th);
    }

private:
    const uint16_t    mTexID;
    const TexDataFlag mFlags;
};

class OutlineData : public TexData{
public:
    OutlineData(uint16_t texid, TexDataFlag flags, uint16_t w, Rml::Colourb c) 
        : TexData(texid, TexDataFlag(flags|TDF_FontTex))
        , width(w), color(c)
    {}

    const uint16_t width;
    const Rml::Colourb color;

    static const OutlineData* ToOutlineData(Rml::TextureHandle th);
};