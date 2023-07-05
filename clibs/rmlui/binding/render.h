#pragma once

#include <binding/context.h>
#include <core/Interface.h>
#include <bgfx/c99/bgfx.h>
#include <core/Interface.h>

struct RenderState {
    glm::vec4 rectVerteices[2] {glm::vec4(0), glm::vec4(0)};
    uint16_t lastScissorId = UINT16_MAX;
    bool needShaderClipRect = false;
    bool needGray = false;
};

class TextureMaterial;
class TextMaterial;
class Uniform;

class Renderer : public Rml::RenderInterface {
public:
    Renderer(const RmlContext* context);
    ~Renderer();
    void Begin() override;
    void End() override;
    void RenderGeometry(Rml::Vertex* vertices, size_t num_vertices, Rml::Index* indices, size_t num_indices, Rml::MaterialHandle mat) override;
    void SetTransform(const glm::mat4x4& transform) override;
    void SetClipRect() override;
    void SetClipRect(const glm::u16vec4& r) override;
    void SetClipRect(glm::vec4 r[2]) override;
    void SetGray(bool enable) override;
    Rml::MaterialHandle CreateTextureMaterial(Rml::TextureId texture, Rml::SamplerFlag flag) override;
    Rml::MaterialHandle CreateRenderTextureMaterial(Rml::TextureId texture, Rml::SamplerFlag flag) override;
    Rml::MaterialHandle CreateFontMaterial(const Rml::TextEffects& effects) override;
    Rml::MaterialHandle CreateDefaultMaterial() override;
    void DestroyMaterial(Rml::MaterialHandle mat) override;

	Rml::FontFaceHandle GetFontFaceHandle(const std::string& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, uint32_t size) override;
    void GetFontHeight(Rml::FontFaceHandle handle, int& ascent, int& descent, int& lineGap) override;
	bool GetUnderline(Rml::FontFaceHandle handle, float& position, float& thickness) override;
	float GetStringWidth(Rml::FontFaceHandle handle, const std::string& string) override;
    float GetRichStringWidth(Rml::FontFaceHandle handle, const std::string& string, std::vector<Rml::image>& images, int& cur_image_idx,float line_height) override;
	void GenerateString(Rml::FontFaceHandle handle, Rml::LineList& lines, const Rml::Color& color, Rml::Geometry& geometry) override;
    void GenerateRichString(Rml::FontFaceHandle handle, Rml::LineList& lines, std::vector<uint32_t>& codepoints, Rml::Geometry& textgeometry, std::vector<std::unique_ptr<Rml::Geometry>> & imagegeometries, std::vector<Rml::image>& images, int& cur_image_idx, float line_height) override;
    float PrepareText(Rml::FontFaceHandle handle,const std::string& string,std::vector<uint32_t>& codepoints,std::vector<int>& groupmap,std::vector<Rml::group>& groups,std::vector<Rml::image>& images,std::vector<Rml::layout>& line_layouts,int start,int num) override;
private:
    void submitScissorRect(bgfx_encoder_t* encoder);
    void setScissorRect(bgfx_encoder_t* encoder, const glm::u16vec4 *r);
    void setShaderScissorRect(bgfx_encoder_t* encoder, const glm::vec4 r[2]);
#ifdef _DEBUG
    void drawDebugScissorRect(bgfx_encoder_t *encoder, uint16_t viewid, uint16_t progid);
#endif

private:
    const RmlContext*     mcontext;
    bgfx_encoder_t*       mEncoder;
    RenderState           state;
    bgfx_texture_handle_t default_tex;
    std::unique_ptr<TextureMaterial> default_tex_mat;
    std::unique_ptr<TextMaterial> default_font_mat;
    std::unique_ptr<Uniform>      clip_uniform;
};
