#pragma once
#include "font.h"

#include <RmlUi/RenderInterface.h>
#include <algorithm>
#include <unordered_map>
#include <bgfx/c99/bgfx.h>

class Renderer : public Rml::RenderInterface {
public:
    Renderer(const RmlContext* context);
    void RenderGeometry(Rml::Vertex* vertices, size_t num_vertices, Rml::Index* indices, size_t num_indices,  Rml::TextureHandle texture, Rml::SamplerFlag flags) override;
    bool LoadTexture(Rml::TextureHandle& handle, Rml::Size& dimensions, const std::string& path) override;
    void ReleaseTexture(Rml::TextureHandle texture) override;
    void SetTransform(const glm::mat4x4& transform) override;
    void SetClipRect() override;
    void SetClipRect(const glm::u16vec4& r) override;
    void SetClipRect(glm::vec4 r[2]) override;

public:
    // will delete buffer
    bool UpdateTexture(Rml::TextureHandle texhandle, const Rect &rt, uint8_t *buffer);
    void Begin();
    void Frame();

public:
    void UpdateViewRect();
    // bool CalcScissorRectPlane(const glm::mat4 &transform, const Rect &rect, glm::vec4 planes[4]);
    // void SubmitScissorRect();

private:
    const RmlContext*       mcontext;
    bgfx_encoder_t*         mEncoder;

    struct ScissorRect{
        glm::vec4 rectVerteices[2]{glm::vec4(0), glm::vec4(0)};
        bool needShaderClipRect = false;
        void submitScissorRect(bgfx_encoder_t* encoder, const shader_info &si);

        #ifdef _DEBUG
        void drawDebugScissorRect(bgfx_encoder_t *encoder, uint16_t viewid, uint16_t progid);
        #endif //_DEBUG
    };

    ScissorRect mScissorRect;
};
