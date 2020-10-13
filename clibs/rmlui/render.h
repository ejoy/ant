#include <RmlUi/Core/RenderInterface.h>
#include <algorithm>
#include <unordered_map>

struct GeometryBuffer{
    std::vector<Rml::Vertex>    mvertices;
    std::vector<int>            mindices;
    GeometryBuffer(){
        Reset();
    }

    void Reset(){
        //mvertices.reserve(std::max({mvertices.size(), decltype(mvertices)::size_type(2048)}));
        mvertices.reserve(std::max(mvertices.size(), size_t(2048)));
        mindices.reserve(std::max(mindices.size(), size_t(4096)));
        mvertices.resize(0);
        mindices.resize(0);
    }
};

struct RenderBatch{
    uint32_t vb_start;
    uint32_t vb_num;

    uint32_t ib_start;
    uint32_t ib_num;

    Rml::Vector2f       offset;
    Rml::TextureHandle  tex;
};

using RenderBatchArray = std::vector<RenderBatch>;
struct TexInfo{
    uint16_t        texid;
    Rml::Vector2i   dim;
};
using TexMap = std::unordered_map<Rml::String, TexInfo>;

struct HW_Interface{
    uint16_t (*create_texture)(const uint8_t *data, uint32_t numbytes, const char* flags, bool source);
    void (*destory_texture)(uint16_t texid);
    void (*get_texture_dimension)(uint16_t texid, int* w, int *h);
};

class Renderer : public Rml::RenderInterface {
public:
    Renderer(HW_Interface i) : mHWI(i){}

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
    void Submit();
    const GeometryBuffer& GetGeometryBuffer() const {return mGeoBuffer;}
    const RenderBatchArray& GetRenderBatchs() const { return mRenderBatches;}
    const Rml::Matrix4f& GetTransform() const { return mTransform;}
    struct Rect {int x, y, w, h;};
    const Rect& GetScissorRect() const { return mScissorRect;}
    void AddTextureId(const Rml::String &key, uint16_t texid, const Rml::Vector2i &dim) {mTexMap[key] = {texid, dim};}
private:
    RenderBatchArray    mRenderBatches;
    GeometryBuffer      mGeoBuffer;
    Rml::Matrix4f       mTransform = Rml::Matrix4f::Identity();
    Rect                mScissorRect = {0, 0, 0, 0};
    HW_Interface        mHWI;

    TexMap              mTexMap;
};
