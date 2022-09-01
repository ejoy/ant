#pragma once

#include <binding/context.h>
#include <core/Interface.h>
#include <bgfx/c99/bgfx.h>

struct RenderState {
    glm::vec4 rectVerteices[2] {glm::vec4(0), glm::vec4(0)};
    uint16_t lastScissorId = UINT16_MAX;
    bool needShaderClipRect = false;
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
    void ReleaseTexture(Rml::TextureHandle texture) override;
    void SetTransform(const glm::mat4x4& transform) override;
    void SetClipRect() override;
    void SetClipRect(const glm::u16vec4& r) override;
    void SetClipRect(glm::vec4 r[2]) override;
    Rml::MaterialHandle CreateTextureMaterial(Rml::TextureHandle texture, Rml::SamplerFlag flag) override;
    Rml::MaterialHandle CreateFontMaterial(const Rml::TextEffects& effects) override;
    Rml::MaterialHandle CreateDefaultMaterial() override;
    void DestroyMaterial(Rml::MaterialHandle mat) override;

	Rml::FontFaceHandle GetFontFaceHandle(const std::string& family, Rml::Style::FontStyle style, Rml::Style::FontWeight weight, uint32_t size) override;
	int GetLineHeight(Rml::FontFaceHandle handle) override;
	int GetBaseline(Rml::FontFaceHandle handle) override;
	void GetUnderline(Rml::FontFaceHandle handle, float& position, float& thickness) override;
	int GetStringWidth(Rml::FontFaceHandle handle, const std::string& string) override;
	void GenerateString(Rml::FontFaceHandle handle, Rml::LineList& lines, const Rml::Color& color, Rml::Geometry& geometry) override;

private:
    void submitScissorRect(bgfx_encoder_t* encoder);
    void setScissorRect(bgfx_encoder_t* encoder, const glm::u16vec4 *r);
    void setShaderScissorRect(bgfx_encoder_t* encoder, const glm::vec4 r[2]);
#ifdef _DEBUG
    void drawDebugScissorRect(bgfx_encoder_t *encoder, uint16_t viewid, uint16_t progid);
#endif

private:
    const RmlContext*   mcontext;
    bgfx_encoder_t*     mEncoder;
    RenderState         state;
    Rml::TextureHandle  default_tex;
    std::unique_ptr<TextureMaterial> default_tex_mat;
    std::unique_ptr<TextMaterial> default_font_mat;
    std::unique_ptr<Uniform>      clip_uniform;
};
