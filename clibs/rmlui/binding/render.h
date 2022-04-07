#pragma once

#include "font.h"
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
    bool LoadTexture(Rml::TextureHandle& handle, Rml::Size& dimensions, const std::string& path) override;
    void ReleaseTexture(Rml::TextureHandle texture) override;
    void SetTransform(const glm::mat4x4& transform) override;
    void SetClipRect() override;
    void SetClipRect(const glm::u16vec4& r) override;
    void SetClipRect(glm::vec4 r[2]) override;
    Rml::MaterialHandle CreateTextureMaterial(Rml::TextureHandle texture, Rml::SamplerFlag flag) override;
    Rml::MaterialHandle CreateFontMaterial(const Rml::TextEffects& effects) override;
    void DestroyMaterial(Rml::MaterialHandle mat) override;

public:
    // will delete buffer
    bool UpdateTexture(Rml::TextureHandle texhandle, uint16_t x, uint16_t y, uint16_t w, uint16_t h, uint8_t *buffer);

public:
    void UpdateViewRect();
    // bool CalcScissorRectPlane(const glm::mat4 &transform, const Rect &rect, glm::vec4 planes[4]);
    // void SubmitScissorRect();

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
    std::unique_ptr<TextureMaterial> default_tex_mat;
    std::unique_ptr<TextMaterial> default_font_mat;
    std::unique_ptr<Uniform>      clip_uniform;
};
