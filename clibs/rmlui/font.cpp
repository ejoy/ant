#include "font.h"

extern "C"{
#include "font/font_manager.h"
}

#include <RmlUi/Core.h>
#include <cassert>

//static
const Rml::String FontInterface::FONT_TEX_NAME("?FONT_TEX");

static inline FamilyFlag
to_FamilyFlag(Rml::Style::FontStyle s, Rml::Style::FontWeight w){
    int flags = 0;
    if (s == Rml::Style::FontStyle::Italic){
        flags |= FF_ITALIC;
    }

    if (w == Rml::Style::FontWeight::Bold){
        flags |= FF_Blod;
    }

    return static_cast<FamilyFlag>(flags);
}

static inline Rml::String
to_FontId_key(const Rml::String &family, FamilyFlag f){
    return family + std::to_string(f);
}

bool FontInterface::LoadFontFace(const Rml::String& file_name, bool fallback_face){
    const FamilyFlag flags = to_FamilyFlag(Rml::Style::FontStyle::Normal, Rml::Style::FontWeight::Normal);
    Rml::String family;
    

    auto ifile = Rml::GetFileInterface();
    auto fh = ifile->Open(file_name);
    if (!fh)
        return false;

    ifile->Seek(fh, 0, SEEK_END);
    const uint32_t filesize = ifile->Tell(fh);
    ifile->Seek(fh, 0, SEEK_SET);

    std::vector<uint8_t>    buffer(filesize);
    ifile->Read(&buffer[0], filesize, fh);
    ifile->Close(fh);

    int fontid = font_manager_addfont(mfontmgr, &buffer[0], 1);
    family.resize(128);
    int namelen = 0;
    font_manager_family_name(mfontmgr, fontid, &family[0], &namelen);

    const auto key = to_FontId_key(family, flags);
    mfontids[key] = fontid;
    return true;
}

bool FontInterface::LoadFontFace(const Rml::byte* data, int data_size, const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, bool fallback_face) {
    const FamilyFlag flags = to_FamilyFlag(style, weight);
    const auto key = to_FontId_key(family, flags);

    if (mfontids.find(key) == mfontids.end()){
        auto fontid = font_manager_addfont_with_family(mfontmgr, data, family.c_str(), (FamilyFlag)flags);
        mfontids[key] = fontid;
        return (fontid >=0);
    }

    return true;
}

Rml::FontFaceHandle FontInterface::GetFontFaceHandle(const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, int size){
    
    const auto key = to_FontId_key(family, to_FamilyFlag(style, weight));
    const auto found = mfontids.find(key);
    if (found != mfontids.end()){
        int fontid = found->second;
        size_t idx = mFontFaces.size();
        mFontFaces.push_back(FontFace{fontid, size});
        return static_cast<Rml::FontFaceHandle>(idx);
    }

    return static_cast<Rml::FontFaceHandle>(-1);
}

// Rml::FontEffectsHandle FontInterface::PrepareFontEffects(Rml::FontFaceHandle handle, const Rml::FontEffectList &font_effects){

// }

int FontInterface::GetSize(Rml::FontFaceHandle handle){
    
    size_t idx = static_cast<size_t>(handle);
    const auto &face = mFontFaces[idx];
    return face.fontsize;
}

static inline struct font_glyph
get_glyph(struct font_manager *F, const FontFace &face, int codepoint){
    struct font_glyph g;
    if (font_manager_touch(F, face.fontid, codepoint, &g)){
        font_manager_update(F, face.fontid, codepoint, &g, NULL);
    }

    font_manager_scale(F, &g, face.fontsize);
    return g;
}

int FontInterface::GetXHeight(Rml::FontFaceHandle handle){
    
    size_t idx = static_cast<size_t>(handle);
    const auto &face = mFontFaces[idx];

    struct font_glyph g = get_glyph(mfontmgr, face, 'x');
    return g.h;
}

int FontInterface::GetLineHeight(Rml::FontFaceHandle handle){
    
    size_t idx = static_cast<size_t>(handle);
    const auto &face = mFontFaces[idx];

    int ascent, descent, lineGap;
    font_manager_fontheight(mfontmgr, face.fontid, face.fontsize, &ascent, &descent, &lineGap);
    return ascent - descent + lineGap;
}

int FontInterface::GetBaseline(Rml::FontFaceHandle handle){
    
    size_t idx = static_cast<size_t>(handle);
    const auto &face = mFontFaces[idx];

    int ascent, descent, lineGap;
    font_manager_fontheight(mfontmgr, face.fontid, face.fontsize, &ascent, &descent, &lineGap);

    return descent + (ascent - descent) / 2;
}

float FontInterface::GetUnderline(Rml::FontFaceHandle handle, float &thickness){
    
    size_t idx = static_cast<size_t>(handle);
    const auto &face = mFontFaces[idx];

    int ascent, descent, lineGap;
    font_manager_fontheight(mfontmgr, face.fontid, face.fontsize, &ascent, &descent, &lineGap);

    return descent;
}

int FontInterface::GetStringWidth(Rml::FontFaceHandle handle, const Rml::String& string, Rml::Character prior_character /*= Character::Null*/){
    
    const auto &face = mFontFaces[static_cast<size_t>(handle)];

    int width = 0;
    for (auto itc = Rml::StringIteratorU8(string); itc; ++itc){
        auto glyph = get_glyph(mfontmgr, face, (int)*itc);
        width += glyph.advance_x;
    }

    return width;
}

int FontInterface::GenerateString(Rml::FontFaceHandle handle, Rml::FontEffectsHandle font_effects_handle, 
    const Rml::String& string, 
    const Rml::Vector2f& position, 
    const Rml::Colourb& colour,
    Rml::GeometryList& geometrys){
	int width = 0;

	geometrys.resize(1);
	Rml::Geometry& geometry = geometrys[0];

	//geometry.SetTexture(&texture);

	auto& vertices = geometry.GetVertices();
	auto& indices = geometry.GetIndices();

	vertices.reserve(string.size() * 4);
	indices.reserve(string.size() * 6);

    const auto&face = mFontFaces[static_cast<size_t>(handle)];

	Rml::Vector2f pos = position.Round();

	for (auto it_char = Rml::StringIteratorU8(string); it_char; ++it_char)
	{
		int codepoint = (int)*it_char;

        struct font_glyph g;
        if (font_manager_touch(mfontmgr, face.fontid, codepoint, &g)){
            font_manager_update(mfontmgr, face.fontid, codepoint, &g, NULL);
        }

        uint16_t uv_w = g.w, uv_h = g.h;
        font_manager_scale(mfontmgr, &g, face.fontsize);

		// Generate the geometry for the character.
		vertices.resize(vertices.size() + 4);
		indices.resize(indices.size() + 6);

        int16_t u0 = g.u * (0x8000 / FONT_MANAGER_TEXSIZE);
        int16_t v0 = g.v * (0x8000 / FONT_MANAGER_TEXSIZE);

        int16_t u1 = (g.u + uv_w) * (0x8000 / FONT_MANAGER_TEXSIZE);
        int16_t v1 = (g.v + uv_h) * (0x8000 / FONT_MANAGER_TEXSIZE);

		Rml::GeometryUtilities::GenerateQuad(
			&vertices[0] + (vertices.size() - 4),
			&indices[0] + (indices.size() - 6),
			(pos + Rml::Vector2f(g.offset_x, g.offset_y)).Round(),
			Rml::Vector2f(g.w, g.h),
			colour,
			Rml::Vector2f(u0, v0),
            Rml::Vector2f(u1, v1),
			(int)vertices.size() - 4
		);

		width += g.advance_x;
		pos.x += g.advance_x;
	}

	return width;
}

int FontInterface::GetVersion(Rml::FontFaceHandle handle){
    return 1;
}