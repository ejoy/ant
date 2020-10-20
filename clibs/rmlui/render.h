#pragma once
#include <RmlUi/Core/RenderInterface.h>
#include <algorithm>
#include <unordered_map>

#include "util.h"

struct TexInfo{
    uint16_t        texid;
    Rml::Vector2i   dim;
};
using TexMap = std::unordered_map<Rml::String, TexInfo>;

class HWInterface;
class Renderer : public Rml::RenderInterface {
public:
    Renderer(HWInterface *i) : mHWI(i){}
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
    void AddTextureId(const Rml::String &key, uint16_t texid, const Rml::Vector2i &dim) {mTexMap[key] = {texid, dim};}
private:
    Rml::Matrix4f       mTransform = Rml::Matrix4f::Identity();
    Rect                mScissorRect = {0, 0, 0, 0};
    HWInterface         *mHWI;

    TexMap              mTexMap;
};
