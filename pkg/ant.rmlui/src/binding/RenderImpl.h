#pragma once

#include <core/Interface.h>
#include <bgfx/c99/bgfx.h>
#include <core/Interface.h>
#include <map>
#include <string>
#include <stdint.h>

struct lua_State;
struct font_manager;

namespace Rml {

struct Shader {
    std::map<std::string, uint16_t> uniforms;

    int font;
    int font_outline;
    int font_shadow;
    int image;

    //with clip rect
    int font_cr;
    int font_outline_cr;
    int font_shadow_cr;
    int image_cr;
    int image_gray;
    int image_cr_gray;

    #ifdef _DEBUG
    uint16_t debug_draw;
    #endif //_DEBUG

    uint16_t find_uniform(const char* name) const {
        auto iter = uniforms.find(name);
        if (iter != uniforms.end()) {
            return iter->second;
        }
        return UINT16_MAX;
    }
};

struct RendererContext {
    struct font_manager* font_mgr;
    struct Shader        shader;
    uint16_t             viewid;
};

struct RenderState {
    glm::vec4 rectVerteices[2] {glm::vec4(0), glm::vec4(0)};
    uint16_t lastScissorId = UINT16_MAX;
    bool needShaderClipRect = false;
};

class TextureMaterial;
class TextMaterial;
class Uniform;

class RenderImpl final : public Render {
public:
    RenderImpl(lua_State* L, int idx);
    ~RenderImpl();
    void Begin() override;
    void End() override;
    void RenderGeometry(Vertex* vertices, size_t num_vertices, Index* indices, size_t num_indices, Material* mat) override;
    void SetTransform(const glm::mat4x4& transform) override;
    void SetClipRect() override;
    void SetClipRect(const glm::u16vec4& r) override;
    void SetClipRect(glm::vec4 r[2]) override;
    Material* CreateTextureMaterial(TextureId texture, SamplerFlag flag) override;
    Material* CreateRenderTextureMaterial(TextureId texture, SamplerFlag flag) override;
    Material* CreateFontMaterial(const TextEffect& effect) override;
    Material* CreateDefaultMaterial() override;
    void DestroyMaterial(Material* mat) override;

	FontFaceHandle GetFontFaceHandle(const std::string& family, Style::FontStyle style, Style::FontWeight weight, uint32_t size) override;
    void GetFontHeight(FontFaceHandle handle, int& ascent, int& descent, int& lineGap) override;
	bool GetUnderline(FontFaceHandle handle, float& position, float& thickness) override;
    float GetFontWidth(FontFaceHandle handle, uint32_t codepoint) override;
	void GenerateString(FontFaceHandle handle, LineList& lines, const Color& color, Geometry& geometry) override;
    void GenerateRichString(FontFaceHandle handle, LineList& lines, std::vector<std::vector<layout>> layouts, std::vector<uint32_t>& codepoints, Geometry& textgeometry, std::vector<std::unique_ptr<Geometry>> & imagegeometries, std::vector<image>& images, int& cur_image_idx, float line_height) override;
    float PrepareText(FontFaceHandle handle,const std::string& string,std::vector<uint32_t>& codepoints,std::vector<int>& groupmap,std::vector<group>& groups,std::vector<image>& images,std::vector<layout>& line_layouts,int start,int num) override;
private:
    void submitScissorRect(bgfx_encoder_t* encoder);
    void setScissorRect(bgfx_encoder_t* encoder, const glm::u16vec4 *r);
    void setShaderScissorRect(bgfx_encoder_t* encoder, const glm::vec4 r[2]);
#ifdef _DEBUG
    void drawDebugScissorRect(bgfx_encoder_t *encoder, uint16_t viewid, uint16_t progid);
#endif

private:
    RendererContext       context;
    bgfx_encoder_t*       mEncoder;
    RenderState           state;
    bgfx_texture_handle_t default_tex;
    bgfx_vertex_layout_t  layout;
    std::unique_ptr<TextureMaterial> default_tex_mat;
    std::unique_ptr<TextMaterial> default_font_mat;
    std::unique_ptr<Uniform>      clip_uniform;
};
}
