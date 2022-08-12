#include "pch.h"
#include "font.h"
#include "render.h"
#include "utf8.h"
#include <core/Core.h>
#include <memory.h>

namespace Rml {

union FontFace {
	struct {
		uint32_t fontid;
		uint32_t pixelsize;
	};
	uint64_t handle;
};

FontEngine::FontEngine(const RmlContext* context)
	: mcontext(context)
{
	SetFontEngineInterface(this);
}

FontFaceHandle FontEngine::GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, uint32_t size){
    font_manager* F = mcontext->font_mgr;
    const char* name = "宋体";
    if (!family.empty())
        name = family.c_str();
    int fontid = F->font_manager_addfont_with_family(F, name);
    if (fontid <= 0) {
        return static_cast<FontFaceHandle>(0);
    }
    FontFace face;
    face.fontid = (uint32_t)fontid;
    face.pixelsize = size;
    return face.handle;
}

static struct font_glyph GetGlyph(const RmlContext* mcontext, const FontFace& face, int codepoint, struct font_glyph* og_ = nullptr) {
    struct font_glyph g, og;
    font_manager* F = mcontext->font_mgr;
    if (0 == F->font_manager_glyph(F, face.fontid, codepoint, face.pixelsize, &g, &og)) {
        auto ri = static_cast<Renderer*>(GetRenderInterface());
        const uint32_t bufsize = og.w * og.h;
        uint8_t *buffer = new uint8_t[bufsize];
        memset(buffer, 0, bufsize);
        if (NULL == F->font_manager_update(F, face.fontid, codepoint, &og, buffer)) {
            ri->UpdateTexture(mcontext->font_tex.texid, og.u, og.v, og.w, og.h, buffer);
        }
        else {
            delete[] buffer;
        }
    }
    if (og_)
        *og_ = og;
    return g;
}

int FontEngine::GetLineHeight(FontFaceHandle handle) {
    int ascent, descent, lineGap;
    font_manager* F = mcontext->font_mgr;
    FontFace face;
    face.handle = handle;
    F->font_manager_fontheight(F, face.fontid, face.pixelsize, &ascent, &descent, &lineGap);
    return ascent - descent + lineGap;
}

int FontEngine::GetBaseline(FontFaceHandle handle) {
    int ascent, descent, lineGap;
    font_manager* F = mcontext->font_mgr;
    FontFace face;
    face.handle = handle;
    F->font_manager_fontheight(F, face.fontid, face.pixelsize, &ascent, &descent, &lineGap);
    return -descent + lineGap;
}

void FontEngine::GetUnderline(FontFaceHandle handle, float& position, float &thickness){
    font_manager* F = mcontext->font_mgr;
    FontFace face;
    face.handle = handle;
    F->font_manager_underline(F, face.fontid, face.pixelsize, &position, &thickness);
}

int FontEngine::GetStringWidth(FontFaceHandle handle, const std::string& string){
    FontFace face;
    face.handle = handle;
    int width = 0;
    for (auto c : utf8::view(string)) {
        auto glyph = GetGlyph(mcontext, face, c);
        width += glyph.advance_x;
    }
    return width;
}

// why 32768, which want to use vs_uifont.sc shader to render font
// and vs_uifont.sc also use in runtime font render.
// the runtime font renderer store vertex position in int16
// when it pass to shader, it convert from int16, range from: [-32768, 32768], to [-1.0, 1.0]
// why store in uint16 ? because bgfx not support ....
#define MAGIC_FACTOR    32768.f

void FontEngine::GenerateString(FontFaceHandle handle, LineList& lines, const Color& color, Geometry& geometry){
    auto& vertices = geometry.GetVertices();
    auto& indices = geometry.GetIndices();
    vertices.clear();
    indices.clear();
    for (size_t i = 0; i < lines.size(); ++i) {
        Line& line = lines[i];
        vertices.reserve(vertices.size() + line.text.size() * 4);
        indices.reserve(indices.size() + line.text.size() * 6);

        FontFace face;
        face.handle = handle;
        const Point fonttexel(1.f / mcontext->font_tex.width, 1.f / mcontext->font_tex.height);

        int x = int(line.position.x + 0.5f), y = int(line.position.y + 0.5f);
        for (auto codepoint : utf8::view(line.text)) {

            struct font_glyph og;
            auto g = GetGlyph(mcontext, face, codepoint, &og);

            // Generate the geometry for the character.
            const int x0 = x + g.offset_x;
            const int y0 = y + g.offset_y;
            const int16_t u0 = g.u;
            const int16_t v0 = g.v;

            const float scale = FONT_POSTION_FIX_POINT / MAGIC_FACTOR;
            geometry.AddRectFilled(
                { x0 * scale, y0 * scale, g.w * scale, g.h * scale },
                { u0 * fonttexel.x, v0 * fonttexel.y ,og.w * fonttexel.x , og.h * fonttexel.y },
                color
            );

            //x += g.advance_x + (dim.x - olddim.x);
            x += g.advance_x;
        }

        line.width = x - int(line.position.x + 0.5f);
    }
}
}
