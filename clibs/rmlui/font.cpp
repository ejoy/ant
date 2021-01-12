#include "pch.h"
#include "font.h"
#include "render.h"
#include "fonteffect.h"

extern "C"{
#include "../font/font_manager.h"
#include "../font/truetype.h"
}

#include <RmlUi/Core.h>
#include <RmlUi/GeometryUtilities.h>
#include <cassert>
#include <cstring>
#include <variant>

bool FontEngine::IsFontTexResource(const Rml::String &sourcename) const{
    return SDFFontEffect::IsFontTexResource(sourcename);
}

Rml::TextureHandle FontEngine::GetFontTexHandle(const Rml::String &sourcename, Rml::Size& texture_dimensions) const{
    auto itfound = mFontResources.find(sourcename);
    if (itfound == mFontResources.end()){
        return Rml::TextureHandle(0);
    }

    texture_dimensions.w = mcontext->font_tex.width;
    texture_dimensions.h = mcontext->font_tex.height;
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

struct TextEffectVisitor {
    const RmlContext* context = 0;
    const SDFFontEffect* result = 0;

    TextEffectVisitor(const RmlContext* ctx)
    : context(ctx)
    { }
    void operator() (Rml::TextShadow const& t) {
        int8_t edgevalue_offset = int8_t(font_manager_sdf_mask(context->font_mgr) * 0.85f);
        result = new SDFFontEffectShadow(
            context->font_tex.texid,
            edgevalue_offset,
            Rml::Point(t.offset_h, t.offset_v),
            t.color
        );
    }
    void operator() (Rml::TextStroke const& t) {
        int8_t edgevalue_offset = int8_t(font_manager_sdf_mask(context->font_mgr) * 0.85f);
        result = new TSDFFontEffectOutline<FontEffectType(FE_Outline|FE_FontTex)>(
            context->font_tex.texid,
            t.width,
            edgevalue_offset,
            t.color
        );
    }
};

Rml::TextEffectsHandle FontEngine::PrepareTextEffects(Rml::FontFaceHandle handle, const Rml::TextEffects& text_effects){
    if (text_effects.empty()) {
        return Rml::TextEffectsHandle(&mDefaultFontEffect);
    }
    if (text_effects.size() != 1){
        assert(false && "not support more than one font effect in single text");
        return 0;
    }
    TextEffectVisitor visitor(mcontext);
    std::visit(visitor, text_effects[0]);
    return Rml::TextEffectsHandle(visitor.result);
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

void FontEngine::GetUnderline(Rml::FontFaceHandle handle, float& position, float &thickness){
    size_t idx = static_cast<size_t>(handle)-1;
    const auto &face = mFontFaces[idx];
    font_manager_underline(mcontext->font_mgr, face.fontid, face.pixelsize, &position, &thickness);
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
FontEngine::FindOrAddFontResource(Rml::TextEffectsHandle font_effects_handle){
    auto sdffe = reinterpret_cast<SDFFontEffect*>(font_effects_handle);
    Rml::String key = sdffe->GenerateKey();

    auto itfound = mFontResources.find(key);
	if (itfound == mFontResources.end()){
        auto result = mFontResources.emplace(key, FontResource{ nullptr, sdffe });
        FontEngine::FontResource& resource = result.first->second;
        resource.tex.reset(new Rml::Texture(key));
        return resource;
    }

    return itfound->second;
}

int FontEngine::GenerateString(
    Rml::FontFaceHandle handle,
    Rml::TextEffectsHandle text_effects_handle,
    const Rml::String& string, const
    Rml::Point& position,
    const Rml::Colourb& colour,
    Rml::GeometryList& geometrys) {
    Rml::Geometry& geometry = geometrys[0];

    const auto& res = FindOrAddFontResource(text_effects_handle);
    geometry.SetTexture(res.tex);

    auto& vertices = geometry.GetVertices();
    auto& indices = geometry.GetIndices();

    vertices.reserve(string.size() * 4);
    indices.reserve(string.size() * 6);

    const size_t fontidx = static_cast<size_t>(handle) - 1;
    const auto& face = mFontFaces[fontidx];

    const Rml::Point fonttexel(1.f / mcontext->font_tex.width, 1.f / mcontext->font_tex.height);

#define FIX_POINT 8
    int x = int(position.x + 0.5f), y = int(position.y + 0.5f);
    for (auto it_char = Rml::StringIteratorU8(string); it_char; ++it_char)
    {
        int codepoint = (int)*it_char;

        struct font_glyph og;
        auto g = GetGlyph(face, codepoint, &og);

        // Generate the geometry for the character.
        const int x0 = x + g.offset_x;
        const int y0 = y + g.offset_y;
        const int16_t u0 = g.u;
        const int16_t v0 = g.v;
        const float scale = FIX_POINT / 65536.f;
        Rml::GeometryUtilities::GenerateRect(
            geometry,
            Rml::Rect {
                { x0 * scale, y0 * scale },
                { g.w * scale, g.h * scale },
            } ,
            colour,
            Rml::Rect {
                { u0 * fonttexel.x, v0 * fonttexel.y },
                { og.w * fonttexel.x , og.h * fonttexel.y }
            }
        );

        //x += g.advance_x + (dim.x - olddim.x);
        x += g.advance_x;
    }

    return x - int(position.x + 0.5f);
}

void FontEngine::GenerateString(
    Rml::FontFaceHandle handle,
    Rml::TextEffectsHandle text_effects_handle,
    Rml::LineList& lines, 
    const Rml::Colourb& colour,
    Rml::GeometryList& geometrys){
    for (size_t i = 0; i < geometrys.size(); ++i) {
        geometrys[i].Release();
    }
    geometrys.resize(1);
    for (size_t i = 0; i < lines.size(); ++i) {
        Rml::Line& line = lines[i];
        line.width = GenerateString(handle, text_effects_handle, line.text, line.position, colour, geometrys);
    }
}

int FontEngine::GetVersion(Rml::FontFaceHandle handle){
    return 1;
}