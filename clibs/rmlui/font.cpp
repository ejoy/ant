#include "font.h"
#include "render.h"
extern "C"{
#include "font/font_manager.h"
#include "font/truetype.h"
}

#include <RmlUi/Core.h>
#include <cassert>
#include <cstring>

//static
const Rml::String FontInterface::FONT_TEX_NAME("?FONT_TEX");

static inline int
load_fontid(struct font_manager *F, const Rml::String &family){
    const char* name = "宋体";
    if (!family.empty() && family != "rmlui-debugger-font")
        name = family.c_str();
    
    return truetype_name((lua_State*)F->L, name);
}

Rml::FontFaceHandle FontInterface::GetFontFaceHandle(const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, int size){
    int fontid = load_fontid(mfontmgr, family);

    if (fontid > 0){
        auto itfound = std::find_if(mFontFaces.begin(), mFontFaces.end(), [=](auto it){
            return it.fontid == fontid && it.pixelsize == size;
        });
        if (itfound == mFontFaces.end()){
            const size_t idx = mFontFaces.size();
            mFontFaces.push_back(FontFace{fontid, size});
            return static_cast<Rml::FontFaceHandle>(idx + 1);
        }
        auto dis = (std::distance(mFontFaces.begin(), itfound));
        return  static_cast<Rml::FontFaceHandle>(dis + 1);
    }

    return static_cast<Rml::FontFaceHandle>(0);
}

Rml::FontEffectsHandle FontInterface::PrepareFontEffects(Rml::FontFaceHandle handle, const Rml::FontEffectList &font_effects){
    

    return 0;
}

int FontInterface::GetSize(Rml::FontFaceHandle handle){
    size_t idx = static_cast<size_t>(handle) - 1;
    const auto &face = mFontFaces[idx];
    return face.pixelsize;
}

struct font_glyph
FontInterface::GetGlyph(const FontFace &face, int codepoint, struct font_glyph *og_){
    struct font_glyph g, og;
    if (0 == font_manager_glyph(mfontmgr, face.fontid, codepoint, face.pixelsize, &g, &og)){
        auto ri = static_cast<Renderer*>(Rml::GetRenderInterface());
        const uint32_t bufsize = og.w * og.h;
        uint8_t *buffer = new uint8_t[bufsize];
        memset(buffer, 0, bufsize);
        if (NULL == font_manager_update(mfontmgr, face.fontid, codepoint, &og, buffer)){
            ri->UpdateTexture(mFontTex.GetHandle(ri), Rect{og.u, og.v, og.w, og.h}, buffer);
        } else {
            delete []buffer;
        }
    }
    if (og_)
        *og_ = og;
    return g;
}

int FontInterface::GetXHeight(Rml::FontFaceHandle handle){
    
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    struct font_glyph g = GetGlyph(face, 'x');
    return g.h;
}

int FontInterface::GetLineHeight(Rml::FontFaceHandle handle){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int ascent, descent, lineGap;
    font_manager_fontheight(mfontmgr, face.fontid, face.pixelsize, &ascent, &descent, &lineGap);
    return ascent - descent + lineGap;
}

int FontInterface::GetBaseline(Rml::FontFaceHandle handle){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int x0, y0, x1, y1;
    font_manager_boundingbox(mfontmgr, face.fontid, face.pixelsize, &x0, &y0, &x1, &y1);
    return -y0;
}

float FontInterface::GetUnderline(Rml::FontFaceHandle handle, float &thickness){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int x0, y0, x1, y1;
    font_manager_boundingbox(mfontmgr, face.fontid, face.pixelsize, &x0, &y0, &x1, &y1);
    return y1;
}

int FontInterface::GetStringWidth(Rml::FontFaceHandle handle, const Rml::String& string, Rml::Character prior_character /*= Character::Null*/){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int width = 0;
    for (auto itc = Rml::StringIteratorU8(string); itc; ++itc){
        auto glyph = GetGlyph(face, (int)*itc);
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

	geometry.SetTexture(&mFontTex);

	auto& vertices = geometry.GetVertices();
	auto& indices = geometry.GetIndices();

	vertices.reserve(string.size() * 4);
	indices.reserve(string.size() * 6);

    const size_t fontidx = static_cast<size_t>(handle)-1;
    const auto&face = mFontFaces[fontidx];

#define FIX_POINT 8
    int16_t x= int16_t(position.x * FIX_POINT), y= int16_t(position.y * FIX_POINT);
	for (auto it_char = Rml::StringIteratorU8(string); it_char; ++it_char)
	{
		int codepoint = (int)*it_char;

        struct font_glyph og;
        auto g = GetGlyph(face, codepoint, &og);

		// Generate the geometry for the character.
		vertices.resize(vertices.size() + 4);
		indices.resize(indices.size() + 6);

        const int16_t x0 = x + g.offset_x * FIX_POINT;
        const int16_t y0 = y + g.offset_y * FIX_POINT;

        const int16_t u0 = g.u;
        const int16_t v0 = g.v;

        const int16_t u1 = g.u + og.w;
        const int16_t v1 = g.v + og.h;

		Rml::GeometryUtilities::GenerateQuad(
			&vertices[0] + (vertices.size() - 4),
			&indices[0] + (indices.size() - 6),
			Rml::Vector2f(x0, y0) / 65536.f,
			Rml::Vector2f(g.w * FIX_POINT, g.h * FIX_POINT) / 65536.f,
			colour,
			Rml::Vector2f(u0, v0) / FONT_MANAGER_TEXSIZE,
            Rml::Vector2f(u1, v1) / FONT_MANAGER_TEXSIZE,
			(int)vertices.size() - 4
		);

		width += g.advance_x;
        x += g.advance_x * FIX_POINT;
	}

	return width;
}

int FontInterface::GetVersion(Rml::FontFaceHandle handle){
    return 1;
}