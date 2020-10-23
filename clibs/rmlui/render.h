#pragma once
#include <RmlUi/Core/RenderInterface.h>
#include <algorithm>
#include <unordered_map>
#include <bgfx/c99/bgfx.h>

struct Rect {
    int x, y, w, h;
};

// Same as BGFX
enum SamplerFlag : uint32_t {
    U_MIRROR        = 0x00000001,
    U_CLAMP         = 0x00000002,
    U_BORDER        = 0x00000003,
    U_SHIFT         = 0,
    U_MASK          = 0x00000003,

    V_MIRROR        = 0x00000004,
    V_CLAMP         = 0x00000008,
    V_BORDER        = 0x0000000c,
    V_SHIFT         = 2,
    V_MASK          = 0x0000000c,

    MIN_POINT       = 0x00000040,
    MIN_ANISOTROPIC = 0x00000080,
    MIN_SHIFT       = 6,
    MIN_MASK        = 0x000000c0,

    MAG_POINT       = 0x00000100,
    MAG_ANISOTROPIC = 0x00000200,
    MAG_SHIFT       = 8,
    MAG_MASK        = 0x00000300,

    MIP_POINT       = 0x00000400,
    MIP_SHIFT       = 10,
    MIP_MASK        = 0x00000400,
};

struct ShaderInfo{
    uint16_t prog;
    uint16_t tex_uniform_idx;
};

struct ShaderContext{
    ShaderInfo font;
    ShaderInfo image;
    uint16_t font_texid;
};

struct TexInfo{
    uint16_t        texid;
    Rml::Vector2i   dim;
};
using TexMap = std::unordered_map<Rml::String, TexInfo>;

class Renderer : public Rml::RenderInterface {
public:
    Renderer(uint16_t viewid, const bgfx_vertex_layout_t *layout, const Rect &vr);
    virtual void RenderGeometry(Rml::Vertex* vertices, int num_vertices, 
                                int* indices, int num_indices, 
                                Rml::TextureHandle texture, const Rml::Vector2f& translation) override;

    virtual void EnableScissorRegion(bool enable) override;
	virtual void SetScissorRegion(int x, int y, int width, int height) override;
    virtual bool LoadTexture(Rml::TextureHandle& texture_handle, Rml::Vector2i& texture_dimensions, const Rml::String& source) override;
    virtual bool GenerateTexture(Rml::TextureHandle& texture_handle, const Rml::byte* source, const Rml::Vector2i& source_dimensions) override;
    virtual void ReleaseTexture(Rml::TextureHandle texture) override;
    virtual void SetTransform(const Rml::Matrix4f* transform) override{mTransform = *transform;}

public:
    // will delete buffer
    bool UpdateTexture(Rml::TextureHandle texhandle, const Rect &rt, uint8_t *buffer);
    void AddTextureId(const Rml::String &key, uint16_t texid, const Rml::Vector2i &dim) {mTexMap[key] = {texid, dim};}
    ShaderContext& GetShaderContext() { return mShaderContext;}
    
private:
    Rml::Matrix4f       mTransform = Rml::Matrix4f::Identity();
    Rect                mScissorRect = {0, 0, 0, 0};
    TexMap              mTexMap;

private:
    uint16_t            mViewId;
    const bgfx_vertex_layout_t* mLayout;
    uint64_t            mRenderState;
    ShaderContext       mShaderContext;
    Rect                mViewRect = {0, 0, 0, 0};
};
