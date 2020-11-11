#include "pch.h"
#include "font.h"
#include "render.h"
#include "fonteffect.h"

extern "C"{
#include "font/font_manager.h"
#include "font/truetype.h"
}

#include <RmlUi/Core.h>
#include <cassert>
#include <cstring>

void FontEngine::RegisterFontEffectInstancer(){
    Rml::Factory::RegisterFontEffectInstancer("outline", mFEIMgr.Create("outline", mcontext));
    Rml::Factory::RegisterFontEffectInstancer("shadow", mFEIMgr.Create("shadow", mcontext));
    Rml::Factory::RegisterFontEffectInstancer("glow", mFEIMgr.Create("glow", mcontext));
}

bool FontEngine::IsFontTexResource(const Rml::String &sourcename) const{
    return SDFFontEffect::IsFontTexResource(sourcename);
}

Rml::TextureHandle FontEngine::GetFontTexHandle(const Rml::String &sourcename, Rml::Vector2i& texture_dimensions) const{
    auto itfound = mFontResources.find(sourcename);
    if (itfound == mFontResources.end()){
        return Rml::TextureHandle(0);
    }

    texture_dimensions.x = mcontext->font_tex.width;
    texture_dimensions.y = mcontext->font_tex.height;
    return Rml::TextureHandle(itfound->second.fe);
}

bool FontEngine::LoadFontFace(const Rml::byte* data, int data_size, const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, bool fallback_face){
    return (family == "rmlui-debugger-font");
}

static inline int
load_fontid(struct font_manager *F, const Rml::String &family){
    const char* name = "宋体";
    if (!family.empty() && family != "rmlui-debugger-font")
        name = family.c_str();
    
    return truetype_name((lua_State*)F->L, name);
}

Rml::FontFaceHandle FontEngine::GetFontFaceHandle(const Rml::String& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, int size){
    int fontid = load_fontid(mcontext->font_mgr, family);

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

Rml::FontEffectsHandle FontEngine::PrepareFontEffects(Rml::FontFaceHandle handle, const Rml::FontEffectList &font_effects){
    if (font_effects.empty())
        return Rml::FontEffectsHandle(&mDefaultFontEffect);

    if (font_effects.size() == 1){
        return Rml::FontEffectsHandle(font_effects[0].get());
    }
    assert(false && "not support more than one font effect in single text");
    return 0;
}

int FontEngine::GetSize(Rml::FontFaceHandle handle){
    size_t idx = static_cast<size_t>(handle) - 1;
    const auto &face = mFontFaces[idx];
    return face.pixelsize;
}

struct font_glyph
FontEngine::GetGlyph(const FontFace &face, int codepoint, struct font_glyph *og_){
    struct font_glyph g, og;
    if (0 == font_manager_glyph(mcontext->font_mgr, face.fontid, codepoint, face.pixelsize, &g, &og)){
        auto ri = static_cast<Renderer*>(Rml::GetRenderInterface());
        const uint32_t bufsize = og.w * og.h;
        uint8_t *buffer = new uint8_t[bufsize];
        memset(buffer, 0, bufsize);
        if (NULL == font_manager_update(mcontext->font_mgr, face.fontid, codepoint, &og, buffer)){
            SDFFontEffectDefault t(mcontext->font_tex.texid);
            ri->UpdateTexture(Rml::TextureHandle(&t), Rect{og.u, og.v, og.w, og.h}, buffer);
        } else {
            delete []buffer;
        }
    }
    if (og_)
        *og_ = og;
    return g;
}

int FontEngine::GetXHeight(Rml::FontFaceHandle handle){
    
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    struct font_glyph g = GetGlyph(face, 'x');
    return g.h;
}

int FontEngine::GetLineHeight(Rml::FontFaceHandle handle){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int ascent, descent, lineGap;
    font_manager_fontheight(mcontext->font_mgr, face.fontid, face.pixelsize, &ascent, &descent, &lineGap);
    return ascent - descent + lineGap;
}

int FontEngine::GetBaseline(Rml::FontFaceHandle handle){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int ascent, descent, lineGap;
    font_manager_fontheight(mcontext->font_mgr, face.fontid, face.pixelsize, &ascent, &descent, &lineGap);
    return -descent + lineGap;
}

float FontEngine::GetUnderline(Rml::FontFaceHandle handle, float &thickness){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int x0, y0, x1, y1;
    font_manager_boundingbox(mcontext->font_mgr, face.fontid, face.pixelsize, &x0, &y0, &x1, &y1);
    return y1;
}

int FontEngine::GetStringWidth(Rml::FontFaceHandle handle, const Rml::String& string, Rml::Character prior_character /*= Character::Null*/){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];

    int width = 0;
    for (auto itc = Rml::StringIteratorU8(string); itc; ++itc){
        auto glyph = GetGlyph(face, (int)*itc);
        width += glyph.advance_x;
    }

    return width;
}

const FontEngine::FontResource& 
FontEngine::FindOrAddFontResource(Rml::FontEffectsHandle font_effects_handle){
    auto sdffe = reinterpret_cast<SDFFontEffect*>(font_effects_handle);
    Rml::String key = sdffe->GenerateKey();

    auto itfound = mFontResources.find(key);
	if (itfound == mFontResources.end()){
        auto &fr = mFontResources[key];
        fr.tex.Set(key);
        fr.fe = sdffe;
        return fr;
    }

    return itfound->second;
}

int FontEngine::GenerateString(Rml::FontFaceHandle handle, Rml::FontEffectsHandle font_effects_handle, 
    const Rml::String& string, 
    const Rml::Vector2f& position, 
    const Rml::Colourb& colour,
    Rml::GeometryList& geometrys){

	geometrys.resize(1);
	Rml::Geometry& geometry = geometrys[0];

    const auto &res = FindOrAddFontResource(font_effects_handle);
    geometry.SetTexture(&res.tex);

	auto& vertices = geometry.GetVertices();
	auto& indices = geometry.GetIndices();

	vertices.reserve(string.size() * 4);
	indices.reserve(string.size() * 6);

    const size_t fontidx = static_cast<size_t>(handle)-1;
    const auto&face = mFontFaces[fontidx];

    const Rml::Vector2f fonttexel(1.f / mcontext->font_tex.width, 1.f / mcontext->font_tex.height);

#define FIX_POINT 8
    int x = int(position.x + 0.5f), y = int(position.y+0.5f);
	for (auto it_char = Rml::StringIteratorU8(string); it_char; ++it_char)
	{
		int codepoint = (int)*it_char;

        struct font_glyph og;
        auto g = GetGlyph(face, codepoint, &og);

		// Generate the geometry for the character.
		vertices.resize(vertices.size() + 4);
		indices.resize(indices.size() + 6);

        const int x0 = x + g.offset_x;
        const int y0 = y + g.offset_y;

        const int16_t u0 = g.u;
        const int16_t v0 = g.v;

        const int16_t u1 = g.u + og.w;
        const int16_t v1 = g.v + og.h;


		auto origin     = Rml::Vector2i(x0, y0);
		auto dim        = Rml::Vector2i(g.w, g.h);
        auto fe = reinterpret_cast<SDFFontEffect*>(font_effects_handle);
        Rml::FontGlyph UNUSED_rml_fg;
        auto olddim = dim;
        fe->GetGlyphMetrics(origin, dim, UNUSED_rml_fg);

        auto to_fixpt = [](const Rml::Vector2i &pt){
            const float scale = FIX_POINT / 65536.f;
            return Rml::Vector2f(pt.x * scale, pt.y * scale);
        };
		Rml::GeometryUtilities::GenerateQuad(
			&vertices[0] + (vertices.size() - 4),
			&indices[0] + (indices.size() - 6),
            to_fixpt(origin), to_fixpt(dim),
			colour,
			Rml::Vector2f(u0, v0) * fonttexel,
            Rml::Vector2f(u1, v1) * fonttexel,
			(int)vertices.size() - 4
		); 

		x += g.advance_x + (dim.x - olddim.x);
	}

	return x - int(position.x + 0.5f);
}

int FontEngine::GetVersion(Rml::FontFaceHandle handle){
    return 1;
}